//
//  WeatherService.swift
//  celon-compass
//

import CoreData
internal import Foundation

final class WeatherService: WeatherServicing {
    private let session: URLSession
    private let ttl: TimeInterval
    private let container: NSPersistentContainer

    init(
        session: URLSession = URLSession(configuration: .ephemeral),
        ttl: TimeInterval = 3 * 3600,
        container: NSPersistentContainer = PersistenceController.shared.container
    ) {
        self.session = session
        self.ttl = ttl
        self.container = container
    }

    @MainActor
    func forecasts(for destinations: [Destination]) async throws -> [UUID: [DayForecast]] {
        var result: [UUID: [DayForecast]] = [:]
        var needsFetch: [Destination] = []

        for destination in destinations {
            guard let id = destination.id else { continue }
            if let cached = WeatherCache.freshForecasts(for: id, ttl: ttl, container: container) {
                result[id] = cached
            } else {
                needsFetch.append(destination)
            }
        }

        guard !needsFetch.isEmpty else { return result }

        let url = try Self.buildURL(for: needsFetch)
        let data: Data
        do {
            (data, _) = try await session.data(from: url)
        } catch {
            throw WeatherError.map(error)
        }

        let responses: [OpenMeteoResponse]
        do {
            responses = needsFetch.count == 1
                ? [try JSONDecoder().decode(OpenMeteoResponse.self, from: data)]
                : try JSONDecoder().decode([OpenMeteoResponse].self, from: data)
        } catch {
            throw WeatherError.map(error)
        }

        guard responses.count == needsFetch.count else {
            throw WeatherError.decoding(DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Open-Meteo returned \(responses.count) results for \(needsFetch.count) destinations")
            ))
        }

        let fetchedAt = Date()
        for (destination, response) in zip(needsFetch, responses) {
            guard let id = destination.id else { continue }
            let forecasts = try response.toDayForecasts()
            try WeatherCache.save(destinationID: id, forecasts: forecasts, fetchedAt: fetchedAt, container: container)
            result[id] = forecasts
        }

        return result
    }

    private static func buildURL(for destinations: [Destination]) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.open-meteo.com"
        components.path = "/v1/forecast"
        components.queryItems = [
            URLQueryItem(name: "latitude", value: destinations.map { String($0.latitude) }.joined(separator: ",")),
            URLQueryItem(name: "longitude", value: destinations.map { String($0.longitude) }.joined(separator: ",")),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max,weathercode"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7")
        ]
        guard let url = components.url else {
            throw WeatherError.network(URLError(.badURL))
        }
        return url
    }
}
