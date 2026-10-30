//
//  UserProfile+CoreDataProperties.swift
//  celon-compass
//

import Foundation
import CoreData

extension UserProfile {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserProfile> {
        return NSFetchRequest<UserProfile>(entityName: "UserProfile")
    }

    @NSManaged public var uid: String
    @NSManaged public var email: String?
    @NSManaged public var displayName: String?
    @NSManaged public var homeCity: String?
    @NSManaged public var interests: String?
    @NSManaged public var tempUnit: String?
    @NSManaged public var rainTolerance: String?
    @NSManaged public var isAnonymous: Bool
    @NSManaged public var updatedAt: Date?
    @NSManaged public var pendingSync: Bool

}

extension UserProfile : Identifiable {

}
