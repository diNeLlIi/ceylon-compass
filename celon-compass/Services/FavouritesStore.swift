//
//  FavouritesStore.swift
//  celon-compass
//
//

import CoreData
import Observation

@MainActor
@Observable
final class FavouritesStore {
    static let shared = FavouritesStore()

    private(set) var destinationIds: Set<UUID> = []
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        reload()
    }

    func isFavourite(_ destinationId: UUID) -> Bool {
        destinationIds.contains(destinationId)
    }

    func toggle(_ destinationId: UUID) {
        if isFavourite(destinationId) {
            remove(destinationId)
        } else {
            add(destinationId)
        }
    }

    func add(_ destinationId: UUID) {
        guard !isFavourite(destinationId) else { return }
        let favourite = Favourite(context: context)
        favourite.id = UUID()
        favourite.destinationId = destinationId
        favourite.createdAt = Date()
        persist()
    }

    func remove(_ destinationId: UUID) {
        let request = Favourite.fetchRequest()
        request.predicate = NSPredicate(format: "destinationId == %@", destinationId as CVarArg)
        (try? context.fetch(request))?.forEach(context.delete)
        persist()
    }

    func removeAll() {
        (try? context.fetch(Favourite.fetchRequest()))?.forEach(context.delete)
        persist()
    }

    private func persist() {
        try? context.save()
        reload()
    }

    private func reload() {
        let all = (try? context.fetch(Favourite.fetchRequest())) ?? []
        destinationIds = Set(all.compactMap(\.destinationId))
    }
}
