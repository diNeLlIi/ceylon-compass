//
//  WidgetTripStore.swift
//  WanderLankaWidget
//
//  Read-only view of the App Group Core Data store. The widget never writes.
//

import CoreData
import Foundation

struct UpcomingStop: Identifiable, Hashable {
    let id: UUID
    let tripID: UUID?
    let name: String
    let date: Date
    let conditionSymbol: String
    let conditionLabel: String
    let high: Double?
    let isGem: Bool

    var temperatureText: String {
        guard let high else { return "—" }
        return "\(Int(high.rounded()))°"
    }
}

enum WidgetTripStore {

    // A widget refresh has a tight time and memory budget, so this is one fetch with a
    // hard limit rather than walking every trip's relationship set.
    static func upcomingStops(limit: Int = 4, now: Date = Date()) -> [UpcomingStop] {
        let context = PersistenceController.shared.container.viewContext
        let startOfToday = Calendar.current.startOfDay(for: now)

        let request = ItineraryStop.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND itinerary != nil AND itinerary.completedAt == nil",
            startOfToday as NSDate
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ItineraryStop.date, ascending: true),
            NSSortDescriptor(keyPath: \ItineraryStop.sortOrder, ascending: true)
        ]
        request.fetchLimit = limit
        request.returnsObjectsAsFaults = false

        guard let stops = try? context.fetch(request) else { return [] }

        return stops.compactMap { stop in
            guard let id = stop.id, let date = stop.date else { return nil }
            let forecast = forecast(for: stop, on: date, context: context)
            return UpcomingStop(
                id: id,
                tripID: stop.itinerary?.id,
                name: stop.poiName ?? "Untitled stop",
                date: date,
                conditionSymbol: forecast?.condition.symbolName ?? "questionmark",
                conditionLabel: forecast?.condition.label ?? "No forecast",
                high: forecast?.high,
                isGem: stop.poiSource == "osm"
            )
        }
    }

    // Reuses the app's cache reader with a generous TTL: a widget showing yesterday's
    // forecast is far better than a widget showing a blank where the weather should be,
    // and the widget has no network path of its own to refresh it.
    private static func forecast(
        for stop: ItineraryStop,
        on date: Date,
        context: NSManagedObjectContext
    ) -> DayForecast? {
        guard let destinationID = stop.destination?.id else { return nil }
        let cached = WeatherCache.freshForecasts(for: destinationID, ttl: 24 * 3600, context: context)
        return cached?.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}
