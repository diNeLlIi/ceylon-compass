//
//  TravelNote+CoreDataProperties.swift
//  celon-compass
//

internal import Foundation
import CoreData

extension TravelNote {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TravelNote> {
        return NSFetchRequest<TravelNote>(entityName: "TravelNote")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var text: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var stop: ItineraryStop?

}

extension TravelNote : Identifiable {

}
