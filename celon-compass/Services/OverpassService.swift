//
//  OverpassService.swift
//  celon-compass
//
//

import CoreData
import Foundation


struct OSMGem: Codable, Equatable {
    let osmId: Int64
    let name: String
    let category: String
    let latitude: Double
    let longitude: Double

    var coordinate: Coordinate { Coordinate(latitude: latitude, longitude: longitude) }
}

protocol OverpassServicing {
    func gems(alongRoute from: Coordinate, to: Coordinate, radiusKm: Double, excluding catalog: [POI]) async throws -> [POI]
}

final class OverpassService: OverpassServicing {
    private static let endpoint = URL(string: "https://overpass-api.de/api/interpreter")!


    private static let tagClauses = [
        "[waterway=waterfall]",
        "[tourism=viewpoint]",
        "[amenity=place_of_worship]",
        "[historic]"
    ]

    private static let formValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()

    private let session: URLSession
    private let ttl: TimeInterval
    private let sampleCount: Int
    private let container: NSPersistentContainer

    init(
        session: URLSession? = nil,
        ttl: TimeInterval = 7 * 24 * 3600,
        sampleCount: Int = 5,
        container: NSPersistentContainer = PersistenceController.shared.container
    ) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 15
            self.session = URLSession(configuration: configuration)
        }
        self.ttl = ttl
        self.sampleCount = sampleCount
        self.container = container
    }

    func gems(alongRoute from: Coordinate, to: Coordinate, radiusKm: Double, excluding catalog: [POI]) async throws -> [POI] {
        let key = GemCache.cacheKey(from: from, to: to, radiusKm: radiusKm)

        if let cached = GemCache.cached(forKey: key, ttl: ttl, container: container) {
            return Self.dedupe(cached, against: catalog).map(POI.init(gem:))
        }

        do {
            let fetched = try await fetchFromOverpass(from: from, to: to, radiusKm: radiusKm)
            // An empty result is never cached: a transient upstream hiccup that decodes to
            // zero elements would otherwise pin "no gems" for the whole 7-day TTL.
            if !fetched.isEmpty {
                try? GemCache.save(cacheKey: key, gems: fetched, fetchedAt: Date(), container: container)
            }
            return Self.dedupe(fetched, against: catalog).map(POI.init(gem:))
        } catch {
            if let stale = GemCache.anyCached(forKey: key, container: container) {
                return Self.dedupe(stale, against: catalog).map(POI.init(gem:))
            }
            // Rethrow rather than returning []: the caller has to be able to tell
            // "the query worked and found nothing" from "the query failed".
            throw error
        }
    }

    private func fetchFromOverpass(from: Coordinate, to: Coordinate, radiusKm: Double) async throws -> [OSMGem] {
        let points = RouteCorridor.samplePoints(from: from, to: to, count: sampleCount)
        let query = Self.buildQuery(points: points, radiusMeters: radiusKm * 1000)

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: Self.formValueAllowed) ?? query
        request.httpBody = "data=\(encodedQuery)".data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OverpassError.badResponse
        }
        guard http.statusCode == 200 else {
            throw http.statusCode == 429 ? OverpassError.rateLimited : OverpassError.badResponse
        }

        let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
        return decoded.elements.compactMap { element -> OSMGem? in
            guard let tags = element.tags,
                  let name = tags["name"]?.trimmingCharacters(in: .whitespaces),
                  !name.isEmpty
            else { return nil }
            return OSMGem(
                osmId: element.id,
                name: name,
                category: Self.category(for: tags),
                latitude: element.lat,
                longitude: element.lon
            )
        }
    }

    private static func buildQuery(points: [Coordinate], radiusMeters: Double) -> String {
        let coordinateList = points.map { "\($0.latitude),\($0.longitude)" }.joined(separator: ",")
        let radius = Int(radiusMeters.rounded())
        let clauses = tagClauses
            .map { "  node(around:\(radius),\(coordinateList))\($0);" }
            .joined(separator: "\n")
        return """
        [out:json][timeout:25];
        (
        \(clauses)
        );
        out body 60;
        """
    }

    private static func category(for tags: [String: String]) -> String {
        if tags["waterway"] == "waterfall" { return "Waterfall" }
        if tags["tourism"] == "viewpoint" { return "Viewpoint" }
        if tags["amenity"] == "place_of_worship" { return "Place of worship" }
        if tags["historic"] != nil { return "Historic site" }
        return "Point of interest"
    }

    
    private static func dedupe(_ gems: [OSMGem], against catalog: [POI]) -> [OSMGem] {
        gems.filter { gem in
            !catalog.contains { poi in
                poi.name.caseInsensitiveCompare(gem.name) == .orderedSame
                    && Haversine.distanceKm(from: poi.coordinate, to: gem.coordinate) <= 0.5
            }
        }
    }
}

enum OverpassError: Error {
    case rateLimited
    case badResponse
}

private struct OverpassResponse: Decodable {
    struct Element: Decodable {
        let id: Int64
        let lat: Double
        let lon: Double
        let tags: [String: String]?
    }
    let elements: [Element]
}
