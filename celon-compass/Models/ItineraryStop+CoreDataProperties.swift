//
//  ItineraryStop+CoreDataProperties.swift
//  celon-compass
//

internal import Foundation
import CoreData

extension ItineraryStop {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ItineraryStop> {
        return NSFetchRequest<ItineraryStop>(entityName: "ItineraryStop")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var sortOrder: Int16
    @NSManaged public var date: Date?
    @NSManaged public var travelNotes: String?
    @NSManaged public var poiName: String?
    @NSManaged public var poiLatitude: Double
    @NSManaged public var poiLongitude: Double
    @NSManaged public var poiCategory: String?
    @NSManaged public var poiSource: String?
    @NSManaged public var itinerary: Itinerary?
    @NSManaged public var destination: Destination?
    @NSManaged public var travelNote: TravelNote?

}

extension ItineraryStop : Identifiable {

}
