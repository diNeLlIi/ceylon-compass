//
//  GemQueryCache+CoreDataProperties.swift
//  celon-compass
//

import Foundation
import CoreData

extension GemQueryCache {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<GemQueryCache> {
        return NSFetchRequest<GemQueryCache>(entityName: "GemQueryCache")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var cacheKey: String?
    @NSManaged public var fetchedAt: Date?
    @NSManaged public var payload: Data?

}

extension GemQueryCache : Identifiable {

}
