//
//  ItineraryCRUDTests.swift
//  celon-compassTests
//
//  Exercises TripRepository against a real in-memory store, including the guarantee that
//  conflict flags are never one mutation stale.
//

import Testing
import CoreData
@testable import celon_compass

@MainActor
struct ItineraryCRUDTests {

    // A fresh store per test: TestStore.controller is shared, so trips from one test
    // would otherwise be visible to the next.
    private func makeContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).container.viewContext
    }

    private func makeDestination(
        _ name: String,
        lat: Double,
        lon: Double,
        in context: NSManagedObjectContext
    ) -> Destination {
        let destination = Destination(context: context)
        destination.id = UUID()
        destination.name = name
        destination.latitude = lat
        destination.longitude = lon
        return destination
    }

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: .now))!
    }

    private func stops(of trip: Itinerary) -> [ItineraryStop] {
        ((trip.stops as? Set<ItineraryStop>) ?? [])
            .filter { !$0.isDeleted }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    // Create

    @Test func createTripPersistsWithPlannedStatus() throws {
        let context = makeContext()
        let repository = TripRepository(context: context)

        let trip = try repository.createTrip(title: "South Coast")

        #expect(trip.id != nil)
        #expect(trip.title == "South Coast")
        #expect(trip.status == "planned")
        #expect(trip.createdAt != nil)
        #expect(!context.hasChanges)
    }

    // Add stop

    @Test func addStopLinksToTripAndKeepsSortIndex() throws {
        let context = makeContext()
        let repository = TripRepository(context: context)
        let trip = try repository.createTrip(title: "Trip")
        let galle = makeDestination("Galle", lat: 6.0535, lon: 80.2210, in: context)

        let stop = try repository.addStop(to: trip, poi: POI(destination: galle), date: day(1), sortIndex: 0)

        #expect(stop.itinerary == trip)
        #expect(stop.poiName == "Galle")
        #expect(stop.sortOrder == 0)
        #expect(stop.destination == galle)
        #expect(stops(of: trip).count == 1)
    }

    @Test func addStopFromAGemCarriesTheOsmSource() throws {
        let context = makeContext()
        let repository = TripRepository(context: context)
        let trip = try repository.createTrip(title: "Trip")
        let gem = POI(gem: OSMGem(osmId: 42, name: "Hidden Falls", category: "Waterfall", latitude: 6.5, longitude: 80.5))

        let stop = try repository.addStop(to: trip, poi: gem, date: day(1), sortIndex: 0)

        #expect(stop.poiSource == POI.Source.osm.rawValue)
        #expect(stop.destination == nil)
    }

    // Reorder

    @Test func reorderPersistsTheNewOrder() throws {
        let context = makeContext()
        let repository = TripRepository(context: context)
        let trip = try repository.createTrip(title: "Trip")
        let a = makeDestination("A", lat: 6.0, lon: 80.0, in: context)
        let b = makeDestination("B", lat: 6.1, lon: 80.1, in: context)
        let first = try repository.addStop(to: trip, poi: POI(destination: a), date: day(1), sortIndex: 0)
        let second = try repository.addStop(to: trip, poi: POI(destination: b), date: day(2), sortIndex: 1)

        try repository.reorder([second, first])

        #expect(second.sortOrder == 0)
        #expect(first.sortOrder == 1)
        #expect(stops(of: trip).map(\.poiName) == ["B", "A"])
    }

    // Move

    @Test func moveStopUpdatesTheTripDateRange() throws {
        let context = makeContext()
        let repository = TripRepository(context: context)
        let trip = try repository.createTrip(title: "Trip")
        let a = makeDestination("A", lat: 6.0, lon: 80.0, in: context)
        let stop = try repository.addStop(to: trip, poi: POI(destination: a), date: day(1), sortIndex: 0)

        try repository.moveStop(stop, to: day(5))

        #expect(stop.date == day(5))
        #expect(trip.endDate == day(5))
    }

    // Delete

    @Test func deleteTripCascadesToItsStops() async throws {
        let context = makeContext()
        let repository = TripRepository(context: context, guardian: DestructiveActionGuard(authenticator: StubAuthenticator(.success)))
        let trip = try repository.createTrip(title: "Trip")
        let a = makeDestination("A", lat: 6.0, lon: 80.0, in: context)
        try repository.addStop(to: trip, poi: POI(destination: a), date: day(1), sortIndex: 0)

        try await repository.deleteTrip(trip)

        let remaining = try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "ItineraryStop"))
        #expect(remaining == 0)
        #expect(try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "Itinerary")) == 0)
    }

    @Test func deleteStopLeavesTheTripIntact() throws {
        let context = makeContext()
        let repository = TripRepository(context: context)
        let trip = try repository.createTrip(title: "Trip")
        let a = makeDestination("A", lat: 6.0, lon: 80.0, in: context)
        let b = makeDestination("B", lat: 6.1, lon: 80.1, in: context)
        let first = try repository.addStop(to: trip, poi: POI(destination: a), date: day(1), sortIndex: 0)
        try repository.addStop(to: trip, poi: POI(destination: b), date: day(2), sortIndex: 1)

        try repository.deleteStop(first)

        #expect(stops(of: trip).count == 1)
        #expect(stops(of: trip).first?.poiName == "B")
    }

    @Test func renameTripPersists() throws {
        let context = makeContext()
        let repository = TripRepository(context: context)
        let trip = try repository.createTrip(title: "Old")

        try repository.renameTrip(trip, to: "New")

        #expect(trip.title == "New")
        #expect(!context.hasChanges)
    }

    // Conflict flags are recomputed inside each mutation — the item 2 regression.

    @Test func addingASecondStopOnTheSameDayFlagsBothWithoutAnExplicitRecompute() throws {
        let context = makeContext()
        let repository = TripRepository(context: context)
        let trip = try repository.createTrip(title: "Trip")
        let a = makeDestination("A", lat: 6.0, lon: 80.0, in: context)
        let b = makeDestination("B", lat: 6.01, lon: 80.01, in: context)

        try repository.addStop(to: trip, poi: POI(destination: a), date: day(1), sortIndex: 0)
        try repository.addStop(to: trip, poi: POI(destination: b), date: day(1), sortIndex: 1)

        #expect(stops(of: trip).allSatisfy { $0.conflictKind == "doubleBooked" })
    }

    @Test func movingADoubleBookedStopClearsTheFlagWithoutAnExplicitRecompute() throws {
        let context = makeContext()
        let repository = TripRepository(context: context)
        let trip = try repository.createTrip(title: "Trip")
        let a = makeDestination("A", lat: 6.0, lon: 80.0, in: context)
        let b = makeDestination("B", lat: 6.01, lon: 80.01, in: context)
        try repository.addStop(to: trip, poi: POI(destination: a), date: day(1), sortIndex: 0)
        let second = try repository.addStop(to: trip, poi: POI(destination: b), date: day(1), sortIndex: 1)

        try repository.moveStop(second, to: day(4))

        #expect(stops(of: trip).allSatisfy { !$0.hasConflict })
    }

    // The exact bug item 2 fixed: reorder used to skip the recompute entirely.
    @Test func reorderRecomputesFlagsRatherThanLeavingThemStale() throws {
        let context = makeContext()
        let repository = TripRepository(context: context)
        let trip = try repository.createTrip(title: "Trip")
        let a = makeDestination("A", lat: 6.0, lon: 80.0, in: context)
        let b = makeDestination("B", lat: 6.01, lon: 80.01, in: context)
        let first = try repository.addStop(to: trip, poi: POI(destination: a), date: day(1), sortIndex: 0)
        let second = try repository.addStop(to: trip, poi: POI(destination: b), date: day(1), sortIndex: 1)
        #expect(stops(of: trip).allSatisfy { $0.hasConflict })

        // Separate the days behind the repository's back, then reorder. Only a recompute
        // inside reorder can clear the now-wrong flags.
        second.date = day(6)
        try repository.reorder([first, second])

        #expect(stops(of: trip).allSatisfy { !$0.hasConflict })
    }

    @Test func deletingTheClashingStopClearsTheSurvivorsFlag() throws {
        let context = makeContext()
        let repository = TripRepository(context: context)
        let trip = try repository.createTrip(title: "Trip")
        let a = makeDestination("A", lat: 6.0, lon: 80.0, in: context)
        let b = makeDestination("B", lat: 6.01, lon: 80.01, in: context)
        let first = try repository.addStop(to: trip, poi: POI(destination: a), date: day(1), sortIndex: 0)
        let second = try repository.addStop(to: trip, poi: POI(destination: b), date: day(1), sortIndex: 1)
        #expect(first.hasConflict)

        try repository.deleteStop(second)

        #expect(!first.hasConflict)
        #expect(first.conflictKind == nil)
    }
}
