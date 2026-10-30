//
//  VisitRecord+CoreDataProperties.swift
//  celon-compass
//

import Foundation
import CoreData

extension VisitRecord {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<VisitRecord> {
        return NSFetchRequest<VisitRecord>(entityName: "VisitRecord")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var visitDate: Date?
    @NSManaged public var rating: Int16
    @NSManaged public var stopName: String?
    @NSManaged public var capturedAt: Date?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var photoData: Data?
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var suggestedStopName: String?
    @NSManaged public var matchConfidence: Double
    @NSManaged public var remoteID: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var pendingSync: Bool
    @NSManaged public var destination: Destination?
    @NSManaged public var note: TravelNote?

}

extension VisitRecord : Identifiable {

}
