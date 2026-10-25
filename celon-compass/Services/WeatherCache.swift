//
//  WeatherCache.swift
//  celon-compass
//


import CoreData
internal import Foundation

enum WeatherCache {
    static func freshForecasts(
        for destinationID: UUID,
        ttl: TimeInterval,
        now: Date = Date(),
        container: NSPersistentContainer = PersistenceController.shared.container
    ) -> [DayForecast]? {
        let context = container.viewContext
        let request = WeatherSnapshot.fetchRequest()
        request.predicate = NSPredicate(format: "destinationID == %@", destinationID as CVarArg)
        request.fetchLimit = 1

        guard let snapshot = try? context.fetch(request).first,
              let fetchedAt = snapshot.fetchedAt,
              now.timeIntervalSince(fetchedAt) < ttl,
              let json = snapshot.dailyJSON,
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode([DayForecast].self, from: data)
    }

    static func save(
        destinationID: UUID,
        forecasts: [DayForecast],
        fetchedAt: Date,
        container: NSPersistentContainer = PersistenceController.shared.container
    ) throws {
        let data = try JSONEncoder().encode(forecasts)
        guard let json = String(data: data, encoding: .utf8) else {
            throw WeatherError.decoding(EncodingError.invalidValue(
                forecasts,
                EncodingError.Context(codingPath: [], debugDescription: "Could not encode forecasts as UTF-8 JSON")
            ))
        }

        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        try context.performAndWait {
            let request = WeatherSnapshot.fetchRequest()
            request.predicate = NSPredicate(format: "destinationID == %@", destinationID as CVarArg)
            request.fetchLimit = 1

            let snapshot = try context.fetch(request).first ?? WeatherSnapshot(context: context)
            if snapshot.id == nil {
                snapshot.id = UUID()
            }
            snapshot.destinationID = destinationID
            snapshot.dailyJSON = json
            snapshot.fetchedAt = fetchedAt

            try context.save()
        }
    }
}
