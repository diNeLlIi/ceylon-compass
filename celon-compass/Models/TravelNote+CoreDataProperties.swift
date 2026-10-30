//
//  TravelNote+CoreDataProperties.swift
//  celon-compass
//

import Foundation
import CoreData

extension TravelNote {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TravelNote> {
        return NSFetchRequest<TravelNote>(entityName: "TravelNote")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var text: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var source: String?
    @NSManaged public var remoteID: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var pendingSync: Bool
    @NSManaged public var stop: ItineraryStop?
    @NSManaged public var visitRecord: VisitRecord?

}

extension TravelNote : Identifiable {

}
