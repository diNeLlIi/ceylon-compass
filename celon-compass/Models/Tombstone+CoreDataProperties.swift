//
//  Tombstone+CoreDataProperties.swift
//  celon-compass
//

import Foundation
import CoreData

extension Tombstone {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tombstone> {
        return NSFetchRequest<Tombstone>(entityName: "Tombstone")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var path: String
    @NSManaged public var createdAt: Date?

}

extension Tombstone : Identifiable {

}
