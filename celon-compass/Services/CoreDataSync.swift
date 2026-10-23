//
//  CoreDataSync.swift
//  celon-compass
//
//  Created by student2 on 2026-10-23.
//

import CoreData

enum CoreDataSync {
    static func upsert(_ dtos: [DestinationDTO]) throws {
        let context = PersistenceController.shared.container.viewContext
        for dto in dtos {
            let request = Destination.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", dto.id)
            let existing = try context.fetch(request).first
            let dest = existing ?? Destination(context: context)
            dest.id = UUID(uuidString: dto.id) ?? UUID()
            dest.name = dto.name
            dest.latitude = dto.latitude
            dest.longitude = dto.longitude
            dest.category = dto.category
            dest.province = dto.province
            dest.district = dto.district
            dest.descriptionText = dto.descriptionText
            dest.imageURL = dto.imageURL
        }
        try context.save()
    }

    static func fetchAll() -> [Destination] {
        let context = PersistenceController.shared.container.viewContext
        let request = Destination.fetchRequest()
        return (try? context.fetch(request)) ?? []
    }
}
