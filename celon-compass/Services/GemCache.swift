//
//  GemCache.swift
//  celon-compass
//
//  Core Data reads or writes for GemQueryCache, mirroring WeatherCache shape
//

import CoreData
import Foundation

enum GemCache {
    static func cached(
        forKey cacheKey: String,
        ttl: TimeInterval,
        now: Date = Date(),
        container: NSPersistentContainer = PersistenceController.shared.container
    ) -> [OSMGem]? {
        guard let row = fetchRow(forKey: cacheKey, context: container.viewContext),
              let fetchedAt = row.fetchedAt,
              now.timeIntervalSince(fetchedAt) < ttl
        else { return nil }
        return decode(row.payload)
    }

    // Ignores TTL entirely: used as a last resort when a live Overpass fetch fails
    static func anyCached(
        forKey cacheKey: String,
        container: NSPersistentContainer = PersistenceController.shared.container
    ) -> [OSMGem]? {
        guard let row = fetchRow(forKey: cacheKey, context: container.viewContext) else { return nil }
        return decode(row.payload)
    }

    static func save(
        cacheKey: String,
        gems: [OSMGem],
        fetchedAt: Date,
        container: NSPersistentContainer = PersistenceController.shared.container
    ) throws {
        let payload = try JSONEncoder().encode(gems)

        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        try context.performAndWait {
            let request = GemQueryCache.fetchRequest()
            request.predicate = NSPredicate(format: "cacheKey == %@", cacheKey)
            request.fetchLimit = 1

            let row = try context.fetch(request).first ?? GemQueryCache(context: context)
            if row.id == nil {
                row.id = UUID()
            }
            row.cacheKey = cacheKey
            row.payload = payload
            row.fetchedAt = fetchedAt

            try context.save()
        }
    }

    
    // Builds before the empty-result guard existed cached "[]" against a live key, which
    // pinned an empty gem section for the full 7-day TTL. Runs once per install to drop them.
    static func purgeEmptyPayloadsOnce(
        defaults: UserDefaults = .standard,
        container: NSPersistentContainer = PersistenceController.shared.container
    ) {
        let key = "gemCache.emptyPayloadsPurged"
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)

        let context = container.newBackgroundContext()
        context.perform {
            let request = GemQueryCache.fetchRequest()
            guard let rows = try? context.fetch(request) else { return }
            for row in rows where (decode(row.payload) ?? []).isEmpty {
                context.delete(row)
            }
            try? context.save()
        }
    }

    static func cacheKey(from: Coordinate, to: Coordinate, radiusKm: Double) -> String {
        func rounded(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }
        return "\(rounded(from.latitude)),\(rounded(from.longitude))"
            + "-\(rounded(to.latitude)),\(rounded(to.longitude))"
            + "-r\(Int(radiusKm.rounded()))"
    }

    private static func fetchRow(forKey cacheKey: String, context: NSManagedObjectContext) -> GemQueryCache? {
        let request = GemQueryCache.fetchRequest()
        request.predicate = NSPredicate(format: "cacheKey == %@", cacheKey)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private static func decode(_ payload: Data?) -> [OSMGem]? {
        guard let payload else { return nil }
        return try? JSONDecoder().decode([OSMGem].self, from: payload)
    }
}
