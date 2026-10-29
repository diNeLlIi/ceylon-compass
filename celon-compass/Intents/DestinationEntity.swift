//
//  DestinationEntity.swift
//  celon-compass
//

import AppIntents
import CoreData

struct DestinationEntity: AppEntity {
    let id: String
    @Property(title: "Name") var name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Destination"
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    static var defaultQuery = DestinationQuery()

    init(destination: Destination) {
        self.id = destination.id?.uuidString ?? UUID().uuidString
        self.name = destination.name ?? "Unknown"
    }
}

struct DestinationQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DestinationEntity] {
        let ids = Set(identifiers)
        return CoreDataSync.fetchAll()
            .filter { ids.contains($0.id?.uuidString ?? "") }
            .map(DestinationEntity.init(destination:))
    }

    func suggestedEntities() async throws -> [DestinationEntity] {
        CoreDataSync.fetchAll()
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
            .map(DestinationEntity.init(destination:))
    }
}
