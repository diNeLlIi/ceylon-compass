//
//  Destination+CoreDataProperties.swift
//  celon-compass
//

import Foundation
import CoreData

extension Destination {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Destination> {
        return NSFetchRequest<Destination>(entityName: "Destination")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var category: String?
    @NSManaged public var province: String?
    @NSManaged public var district: String?
    @NSManaged public var descriptionText: String?
    @NSManaged public var imageURL: String?
    @NSManaged public var stops: NSSet?
    @NSManaged public var visitRecords: NSSet?

}

// generated accessors for stops
extension Destination {

    @objc(addStopsObject:)
    @NSManaged public func addToStops(_ value: ItineraryStop)

    @objc(removeStopsObject:)
    @NSManaged public func removeFromStops(_ value: ItineraryStop)

    @objc(addStops:)
    @NSManaged public func addToStops(_ values: NSSet)

    @objc(removeStops:)
    @NSManaged public func removeFromStops(_ values: NSSet)

}

// accessors for visitRecords
extension Destination {

    @objc(addVisitRecordsObject:)
    @NSManaged public func addToVisitRecords(_ value: VisitRecord)

    @objc(removeVisitRecordsObject:)
    @NSManaged public func removeFromVisitRecords(_ value: VisitRecord)

    @objc(addVisitRecords:)
    @NSManaged public func addToVisitRecords(_ values: NSSet)

    @objc(removeVisitRecords:)
    @NSManaged public func removeFromVisitRecords(_ values: NSSet)

}

extension Destination : Identifiable {

}
