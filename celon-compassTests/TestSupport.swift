//
//  TestSupport.swift
//  celon-compassTests
//

import Foundation
import CoreData
@testable import celon_compass


@MainActor
final class StubAuthenticator: BiometricAuthenticating {
    var biometryKind: BiometryKind = .faceID
    private var results: [BiometricResult]
    private let delay: Duration?
    private(set) var purposes: [AuthPurpose] = []

    var callCount: Int { purposes.count }

    init(_ results: BiometricResult..., delay: Duration? = nil) {
        self.results = results.isEmpty ? [.cancelled] : results
        self.delay = delay
    }

    func authenticate(reason: String, purpose: AuthPurpose) async -> BiometricResult {
        purposes.append(purpose)
        if let delay {
            try? await Task.sleep(for: delay)
        }
        return results.count > 1 ? results.removeFirst() : results[0]
    }
}

@MainActor
enum TestStore {
    static let controller = PersistenceController(inMemory: true)
    static var context: NSManagedObjectContext { controller.container.viewContext }

    static func count(_ entity: String, where format: String, _ argument: CVarArg) throws -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: format, argument)
        return try context.count(for: request)
    }

    static func makeTrip(stopCount: Int = 2) throws -> Itinerary {
        let trip = Itinerary(context: context)
        trip.id = UUID()
        trip.title = "Test trip"
        trip.createdAt = Date()
        for index in 0..<stopCount {
            let stop = ItineraryStop(context: context)
            stop.id = UUID()
            stop.sortOrder = Int16(index)
            stop.itinerary = trip
        }
        try context.save()
        tripIDs[trip.objectID] = trip.id
        return trip
    }


    private static var tripIDs: [NSManagedObjectID: UUID] = [:]

    private static func id(of trip: Itinerary) -> UUID {
        tripIDs[trip.objectID] ?? trip.id!
    }

    static func tripCount(_ trip: Itinerary) throws -> Int {
        try count("Itinerary", where: "id == %@", id(of: trip) as CVarArg)
    }

    static func stopCount(of trip: Itinerary) throws -> Int {
        try count("ItineraryStop", where: "itinerary.id == %@", id(of: trip) as CVarArg)
    }
}

struct TestError: Error, Equatable {}

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var requestCount = 0

    static func reset(handler: ((URLRequest) throws -> (HTTPURLResponse, Data))? = nil) {
        requestHandler = handler
        requestCount = 0
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubURLProtocol.requestCount += 1
        guard let handler = StubURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
