//
//  TripRepository.swift
//  celon-compass
//

import CoreData

@MainActor
struct TripRepository {
    let context: NSManagedObjectContext
    private let guardian: DestructiveActionGuard

    init(context: NSManagedObjectContext, guardian: DestructiveActionGuard? = nil) {
        self.context = context
        self.guardian = guardian ?? DestructiveActionGuard()
    }

    @discardableResult
    func createTrip(title: String) throws -> Itinerary {
        let trip = Itinerary(context: context)
        trip.id = UUID()
        trip.title = title
        trip.createdAt = Date()
        trip.status = "planned"
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return trip
    }

    // Deletes the trip (its stops cascade) only after re-authentication succeeds
    // Nothing is mutated if cancelled or fails
    func deleteTrip(_ trip: Itinerary) async throws {
        try await guardian.perform(reason: "Confirm deleting this trip") {
            guard !trip.isDeleted else { return }
            context.delete(trip)
            do {
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
    }
}
