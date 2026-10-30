//
//  NSManagedObject+Touch.swift
//  celon-compass
//
//  Sets updatedAt to now and marks pendingSync = true on any entity that has those attributes.
//

import CoreData

extension NSManagedObject {

    /// Stamps `updatedAt` and flips `pendingSync` for any entity that carries sync columns.
    /// Safe to call on entities that don't have them — it's a no-op.
    func touch() {
        let entity = self.entity
        if entity.attributesByName["updatedAt"] != nil {
            setValue(Date(), forKey: "updatedAt")
        }
        if entity.attributesByName["pendingSync"] != nil {
            setValue(true, forKey: "pendingSync")
        }
    }
}
