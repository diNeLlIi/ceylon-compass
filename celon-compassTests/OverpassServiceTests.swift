//
//  OverpassServiceTests.swift
//  celon-compassTests
//

import Testing
import CoreData
import Foundation
@testable import celon_compass

@MainActor
struct OverpassServiceTests {
    private let origin = Coordinate(latitude: 6.9271, longitude: 79.8612)
    private let destination = Coordinate(latitude: 5.9483, longitude: 80.4589)

    private func element(id: Int64, name: String?, lat: Double, lon: Double, tag: (String, String)? = nil) -> [String: Any] {
        var tags: [String: String] = [:]
        if let name { tags["name"] = name }
        if let tag { tags[tag.0] = tag.1 }
        return ["type": "node", "id": id, "lat": lat, "lon": lon, "tags": tags]
    }

    private func response(elements: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: ["elements": elements])
    }

    private func okResponse(for request: URLRequest, data: Data) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, data)
    }

    private func rateLimitedResponse(for request: URLRequest) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
        return (response, Data())
    }

    @Test func dropsNodesWithNoNameTag() async throws {
        let data = response(elements: [
            element(id: 1, name: nil, lat: 6.0, lon: 80.0, tag: ("waterway", "waterfall")),
            element(id: 2, name: "Secret Falls", lat: 6.0, lon: 80.0, tag: ("waterway", "waterfall"))
        ])
        StubURLProtocol.reset { [self] request in okResponse(for: request, data: data) }

        let service = OverpassService(session: StubURLProtocol.makeSession(), container: TestStore.controller.container)

        let gems = try await service.gems(alongRoute: origin, to: destination, radiusKm: 11, excluding: [])

        #expect(gems.count == 1)
        #expect(gems.first?.name == "Secret Falls")
        #expect(gems.first?.source == .osm)
    }

    @Test func dedupesOsmNodeMatchingACatalogDestinationByNameAndProximity() async throws {
        let galleFortDestination = Destination(context: TestStore.context)
        galleFortDestination.id = UUID()
        galleFortDestination.name = "Galle Fort"
        galleFortDestination.latitude = 6.0300
        galleFortDestination.longitude = 80.2170
        let catalog = [POI(destination: galleFortDestination)]

        let data = response(elements: [
            // Same name,0 km away: should be dropped
            element(id: 1, name: "Galle Fort", lat: 6.0300, lon: 80.2170, tag: ("historic", "fort")),
            // Different place entirely: survive
            element(id: 2, name: "Jungle Beach", lat: 6.0250, lon: 80.2050, tag: ("tourism", "viewpoint"))
        ])
        StubURLProtocol.reset { [self] request in okResponse(for: request, data: data) }

        let service = OverpassService(session: StubURLProtocol.makeSession(), container: TestStore.controller.container)
        let gems = try await service.gems(alongRoute: origin, to: destination, radiusKm: 12, excluding: catalog)

        #expect(gems.count == 1)
        #expect(gems.first?.name == "Jungle Beach")
    }

    @Test func secondCallWithinTTLIsAPureCacheHit() async throws {
        let data = response(elements: [
            element(id: 1, name: "Lovers Leap", lat: 6.87, lon: 81.05, tag: ("waterway", "waterfall"))
        ])
        StubURLProtocol.reset { [self] request in okResponse(for: request, data: data) }

        let service = OverpassService(session: StubURLProtocol.makeSession(), ttl: 7 * 24 * 3600, container: TestStore.controller.container)
        _ = try await service.gems(alongRoute: origin, to: destination, radiusKm: 15, excluding: [])
        #expect(StubURLProtocol.requestCount == 1)

        let second = try await service.gems(alongRoute: origin, to: destination, radiusKm: 15, excluding: [])
        #expect(StubURLProtocol.requestCount == 1)
        #expect(second.count == 1)
    }

    @Test func rateLimitFallsBackToStaleCacheRatherThanBlocking() async throws {
        let firstData = response(elements: [
            element(id: 1, name: "Ravana Falls", lat: 6.87, lon: 81.06, tag: ("waterway", "waterfall"))
        ])
        StubURLProtocol.reset { [self] request in okResponse(for: request, data: firstData) }

        // ttl: 0 so the second call is forced to treat the cache as stale and re-fetch
        let service = OverpassService(session: StubURLProtocol.makeSession(), ttl: 0, container: TestStore.controller.container)
        let first = try await service.gems(alongRoute: origin, to: destination, radiusKm: 16, excluding: [])
        #expect(first.count == 1)

        StubURLProtocol.reset { [self] request in rateLimitedResponse(for: request) }
        let second = try await service.gems(alongRoute: origin, to: destination, radiusKm: 16, excluding: [])

        #expect(second.count == 1)
        #expect(second.first?.name == "Ravana Falls")
    }
}
