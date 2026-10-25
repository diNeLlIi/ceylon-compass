//
//  FavouritesStoreTests.swift
//  celon-compassTests
//
//

import Testing
import CoreData
@testable import celon_compass

@MainActor
@Suite(.serialized)
struct FavouritesStoreTests {

    @Test func togglingAddsAndRemoves() {
        let store = FavouritesStore(context: TestStore.context)
        let id = UUID()

        #expect(!store.isFavourite(id))
        store.toggle(id)
        #expect(store.isFavourite(id))
        store.toggle(id)
        #expect(!store.isFavourite(id))
    }

    @Test func addIsIdempotentAndRespectsTheUniquenessConstraint() throws {
        let store = FavouritesStore(context: TestStore.context)
        let id = UUID()

        store.add(id)
        store.add(id)

        #expect(try TestStore.count("Favourite", where: "destinationId == %@", id as CVarArg) == 1)
    }

    @Test func removeAllClearsEverything() {
        let store = FavouritesStore(context: TestStore.context)
        store.add(UUID())
        store.add(UUID())

        store.removeAll()

        #expect(store.destinationIds.isEmpty)
    }

    @Test func survivesTheDestinationRowBeingDeletedAndRecreated() throws {
        let store = FavouritesStore(context: TestStore.context)
        let id = UUID()

        let destination = Destination(context: TestStore.context)
        destination.id = id
        destination.name = "Sigiriya"
        try TestStore.context.save()

        store.add(id)
        #expect(store.isFavourite(id))

        TestStore.context.delete(destination)
        try TestStore.context.save()
        #expect(store.isFavourite(id), "favourite must not depend on the Destination row existing")

        let recreated = Destination(context: TestStore.context)
        recreated.id = id
        recreated.name = "Sigiriya"
        try TestStore.context.save()

        #expect(store.isFavourite(id))
    }

    @Test func favouriteSurvivesCoreDataSyncUpsertOverwrite() throws {
        let store = FavouritesStore(context: TestStore.context)
        let id = UUID().uuidString
        let dto = DestinationDTO(
            id: id,
            name: "Sigiriya",
            latitude: 7.9570,
            longitude: 80.7603,
            category: "Heritage",
            province: "Central",
            district: "Matale",
            descriptionText: "Ancient rock fortress",
            imageURL: "https://example.com/sigiriya.jpg"
        )
        try CoreDataSync.upsert([dto], context: TestStore.context)

        store.add(UUID(uuidString: id)!)
        #expect(store.isFavourite(UUID(uuidString: id)!))

        let renamed = DestinationDTO(
            id: id,
            name: "Sigiriya Rock",
            latitude: dto.latitude,
            longitude: dto.longitude,
            category: dto.category,
            province: dto.province,
            district: dto.district,
            descriptionText: dto.descriptionText,
            imageURL: dto.imageURL
        )
        try CoreDataSync.upsert([renamed], context: TestStore.context)

        #expect(store.isFavourite(UUID(uuidString: id)!), "favourite must survive a catalog re-sync")
    }
}
