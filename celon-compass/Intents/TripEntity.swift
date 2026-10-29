//
//  TripEntity.swift
//  celon-compass
//

import AppIntents
import CoreData

struct TripEntity: AppEntity {
    let id: String
    @Property(title: "Title") var title: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Trip"
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
    static var defaultQuery = TripQuery()

    init(trip: Itinerary) {
        self.id = trip.id?.uuidString ?? UUID().uuidString
        self.title = trip.title ?? "Untitled trip"
    }
}

struct TripQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TripEntity] {
        let ids = Set(identifiers)
        return Self.fetchTrips().filter { ids.contains($0.id?.uuidString ?? "") }.map(TripEntity.init(trip:))
    }

    func suggestedEntities() async throws -> [TripEntity] {
        ActiveTripResolver.activeOrUpcoming(Self.fetchTrips()).map(TripEntity.init(trip:))
    }

    private static func fetchTrips(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    ) -> [Itinerary] {
        let request = Itinerary.fetchRequest()
        return (try? context.fetch(request)) ?? []
    }
}
