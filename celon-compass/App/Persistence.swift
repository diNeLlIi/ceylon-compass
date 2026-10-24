//
//  Persistence.swift
//  celon-compass
//
//  Created by student2 on 2026-09-30.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    
    static let preview = PersistenceController(inMemory: true)

    private static let model: NSManagedObjectModel = {
        guard let url = Bundle.main.url(forResource: "celon_compass", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Unable to load celon_compass Core Data model")
        }
        return model
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "celon_compass", managedObjectModel: Self.model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
