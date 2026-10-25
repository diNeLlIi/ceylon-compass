//
//  Favourite+CoreDataProperties.swift
//  celon-compass
//

internal import Foundation
import CoreData

extension Favourite {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Favourite> {
        return NSFetchRequest<Favourite>(entityName: "Favourite")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var destinationId: UUID?
    @NSManaged public var createdAt: Date?

}

extension Favourite : Identifiable {

}
