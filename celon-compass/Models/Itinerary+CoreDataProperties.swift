//
//  Itinerary+CoreDataProperties.swift
//  celon-compass
//

internal import Foundation
import CoreData

extension Itinerary {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Itinerary> {
        return NSFetchRequest<Itinerary>(entityName: "Itinerary")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var status: String?
    @NSManaged public var stops: NSSet?

}

//accessors for stops.
extension Itinerary {

    @objc(addStopsObject:)
    @NSManaged public func addToStops(_ value: ItineraryStop)

    @objc(removeStopsObject:)
    @NSManaged public func removeFromStops(_ value: ItineraryStop)

    @objc(addStops:)
    @NSManaged public func addToStops(_ values: NSSet)

    @objc(removeStops:)
    @NSManaged public func removeFromStops(_ values: NSSet)

}

extension Itinerary : Identifiable {

}
