//
//  WeatherServiceTests.swift
//  celon-compassTests
//

import Testing
import CoreData
import Foundation
@testable import celon_compass

@MainActor
struct WeatherServiceTests {
    private func makeDestination(latitude: Double = 6.9271, longitude: Double = 79.8612) -> Destination {
        let destination = Destination(context: TestStore.context)
        destination.id = UUID()
        destination.name = "Colombo"
        destination.latitude = latitude
        destination.longitude = longitude
        try? TestStore.context.save()
        return destination
    }

    private func cannedJSON(days: [(temp: Double, code: Int)]) -> Data {
        let time = days.indices.map { "2026-10-\(24 + $0)" }
        let json: [String: Any] = [
            "daily": [
                "time": time,
                "temperature_2m_max": days.map { $0.temp },
                "temperature_2m_min": days.map { $0.temp - 5 },
                "precipitation_probability_max": days.map { _ in 10 },
                "uv_index_max": days.map { _ in 7.0 },
                "weathercode": days.map { $0.code }
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func okResponse(for request: URLRequest, data: Data) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, data)
    }

    @Test func singleDestinationFetchesAndCaches() async throws {
        let destination = makeDestination()
        let data = cannedJSON(days: [(30, 1), (28, 61)])
        StubURLProtocol.reset { [self] request in okResponse(for: request, data: data) }

        let service = WeatherService(session: StubURLProtocol.makeSession(), ttl: 3 * 3600, container: TestStore.controller.container)
        let first = try await service.forecasts(for: [destination])

        #expect(StubURLProtocol.requestCount == 1)
        #expect(first[destination.id!]?.count == 2)
        #expect(first[destination.id!]?.first?.condition == .cloudy)
        #expect(first[destination.id!]?.last?.condition == .rain)

        // Second call within TTL must be a pure cache hit — no second network request.
        let second = try await service.forecasts(for: [destination])
        #expect(StubURLProtocol.requestCount == 1)
        #expect(second[destination.id!]?.count == 2)
    }

    @Test func batchDecodingZipsResponsesToTheRightDestination() async throws {
        let colombo = makeDestination(latitude: 6.9271, longitude: 79.8612)
        let kandy = makeDestination(latitude: 7.2906, longitude: 80.6337)

        let colomboJSON = cannedJSON(days: [(32, 0)])
        let kandyJSON = cannedJSON(days: [(24, 95)])
        let combined = try! JSONSerialization.data(withJSONObject: [
            try! JSONSerialization.jsonObject(with: colomboJSON),
            try! JSONSerialization.jsonObject(with: kandyJSON)
        ])
        StubURLProtocol.reset { [self] request in okResponse(for: request, data: combined) }

        let service = WeatherService(session: StubURLProtocol.makeSession(), ttl: 3 * 3600, container: TestStore.controller.container)
        let result = try await service.forecasts(for: [colombo, kandy])

        #expect(result[colombo.id!]?.first?.condition == .clear)
        #expect(result[kandy.id!]?.first?.condition == .storm)
    }

    @Test func cacheWriteProducesExactlyOneRowPerDestination() async throws {
        let destination = makeDestination()
        let data = cannedJSON(days: [(30, 1)])
        StubURLProtocol.reset { [self] request in okResponse(for: request, data: data) }

        // ttl: 0 forces a real fetch every call, so repeated calls exercise the upsert path.
        let service = WeatherService(session: StubURLProtocol.makeSession(), ttl: 0, container: TestStore.controller.container)
        for _ in 0..<3 {
            _ = try await service.forecasts(for: [destination])
        }

        #expect(StubURLProtocol.requestCount == 3)
        let rowCount = try TestStore.count("WeatherSnapshot", where: "destinationID == %@", destination.id! as CVarArg)
        #expect(rowCount == 1)
    }

    @Test func noConnectionErrorIsDistinguishedFromGenericNetworkError() async {
        let destination = makeDestination()
        StubURLProtocol.reset { _ in throw URLError(.notConnectedToInternet) }

        let service = WeatherService(session: StubURLProtocol.makeSession(), ttl: 3 * 3600, container: TestStore.controller.container)
        do {
            _ = try await service.forecasts(for: [destination])
            Issue.record("expected forecasts(for:) to throw")
        } catch let error as WeatherError {
            switch error {
            case .noConnection: break
            default: Issue.record("expected .noConnection, got \(error)")
            }
        } catch {
            Issue.record("expected WeatherError, got \(error)")
        }
    }
}
