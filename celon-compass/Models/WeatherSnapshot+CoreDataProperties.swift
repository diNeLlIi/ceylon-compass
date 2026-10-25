//
//  WeatherSnapshot+CoreDataProperties.swift
//  celon-compass
//

internal import Foundation
import CoreData

extension WeatherSnapshot {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WeatherSnapshot> {
        return NSFetchRequest<WeatherSnapshot>(entityName: "WeatherSnapshot")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var destinationID: UUID?
    @NSManaged public var dailyJSON: String?
    @NSManaged public var fetchedAt: Date?

}

extension WeatherSnapshot : Identifiable {

}
