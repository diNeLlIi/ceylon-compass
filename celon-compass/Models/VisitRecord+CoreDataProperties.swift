//
//  VisitRecord+CoreDataProperties.swift
//  celon-compass
//

internal import Foundation
import CoreData

extension VisitRecord {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<VisitRecord> {
        return NSFetchRequest<VisitRecord>(entityName: "VisitRecord")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var visitDate: Date?
    @NSManaged public var rating: Int16
    @NSManaged public var note: String?
    @NSManaged public var destination: Destination?

}

extension VisitRecord : Identifiable {

}
