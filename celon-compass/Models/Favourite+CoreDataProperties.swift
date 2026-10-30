//
//  Favourite+CoreDataProperties.swift
//  celon-compass
//

import Foundation
import CoreData

extension Favourite {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Favourite> {
        return NSFetchRequest<Favourite>(entityName: "Favourite")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var destinationId: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var remoteID: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var pendingSync: Bool

}

extension Favourite : Identifiable {

}
