//
//  TestSupport.swift
//  celon-compassTests
//

import Foundation
import CoreData
@testable import celon_compass

/// Scripted stand-in for `BiometricService`. Returns the queued results in order
/// (repeating the last one) and records every request.
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

/// One in-memory Core Data stack for the whole test run. Creating several containers
/// from the same model in one process makes Core Data warn about duplicate entity
/// classes, so tests share one and look up their own objects by id.
@MainActor
enum TestStore {
    static let controller = PersistenceController(inMemory: true)
    static var context: NSManagedObjectContext { controller.container.viewContext }

    static func count(_ entity: String, where format: String, _ argument: CVarArg) throws -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: format, argument)
        return try context.count(for: request)
    }

    /// Creates and saves a trip with `stopCount` stops; returns the trip.
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
        return trip
    }

    static func tripCount(_ trip: Itinerary) throws -> Int {
        try count("Itinerary", where: "id == %@", trip.id! as CVarArg)
    }

    static func stopCount(of trip: Itinerary) throws -> Int {
        try count("ItineraryStop", where: "itinerary.id == %@", trip.id! as CVarArg)
    }
}

struct TestError: Error, Equatable {}
