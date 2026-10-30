//
//  TripReminderScheduler.swift
//  celon-compass
//
//  One 7am local notification per trip day, built from that day's cached forecast for
//  that day's first stop.
//

import CoreData
import Foundation
import UserNotifications

@MainActor
enum TripReminderScheduler {
    static let hour = 7
    private static let prefix = "tripday"

    // iOS keeps at most 64 pending local notifications and silently drops the rest, so
    // only the active trip and the next one are scheduled — not the whole history.
    static let maxScheduledTrips = 2

    static func reschedule(
        trips: [Itinerary],
        context: NSManagedObjectContext,
        center: UNUserNotificationCenter = .current(),
        now: Date = Date()
    ) async {
        await clearAll(center: center)

        guard PreferencesStore.shared.tripRemindersEnabled else { return }

        let upcoming = trips
            .filter { $0.completedAt == nil }
            .filter { ($0.endDate ?? $0.startDate ?? .distantPast) >= Calendar.current.startOfDay(for: now) }
            .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
            .prefix(maxScheduledTrips)

        for trip in upcoming {
            for request in requests(for: trip, context: context, now: now) {
                try? await center.add(request)
            }
        }
    }

    static func clearAll(center: UNUserNotificationCenter = .current()) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // Identifier is trip id + day, so rescheduling replaces a day's reminder in place
    // rather than stacking a second copy on top of it.
    static func identifier(tripID: UUID, day: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return "\(prefix).\(tripID.uuidString).\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private static func requests(
        for trip: Itinerary,
        context: NSManagedObjectContext,
        now: Date
    ) -> [UNNotificationRequest] {
        guard let tripID = trip.id else { return [] }
        let calendar = Calendar.current
        let stops = ((trip.stops as? Set<ItineraryStop>) ?? [])
            .filter { !$0.isDeleted && $0.date != nil }
            .sorted { ($0.date!, $0.sortOrder) < ($1.date!, $1.sortOrder) }

        let byDay = Dictionary(grouping: stops) { calendar.startOfDay(for: $0.date!) }

        return byDay.keys.sorted().compactMap { day -> UNNotificationRequest? in
            guard let stop = byDay[day]?.first else { return nil }
            var fireComponents = calendar.dateComponents([.year, .month, .day], from: day)
            fireComponents.hour = hour
            fireComponents.minute = 0
            // A 7am reminder for a day whose 7am has passed would fire immediately.
            guard let fireDate = calendar.date(from: fireComponents), fireDate > now else { return nil }

            let content = UNMutableNotificationContent()
            content.title = trip.title ?? "Your trip"
            content.body = body(for: stop, on: day, context: context)
            content.sound = .default

            return UNNotificationRequest(
                identifier: identifier(tripID: tripID, day: day),
                content: content,
                // Calendar trigger, not a time interval: the reminder must land at 7am
                // local time on that date even if the device changes time zone en route.
                trigger: UNCalendarNotificationTrigger(dateMatching: fireComponents, repeats: false)
            )
        }
    }

    static func body(for stop: ItineraryStop, on day: Date, context: NSManagedObjectContext) -> String {
        let name = stop.poiName ?? "your next stop"
        guard let destinationID = stop.destination?.id,
              let forecast = WeatherCache.freshForecasts(for: destinationID, ttl: 24 * 3600, context: context)?
                  .first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) })
        else {
            return "\(name) today."
        }
        return "\(name) today — \(Int(forecast.high.rounded()))°, "
            + "\(forecast.condition.label.lowercased()), \(forecast.rainProbability)% rain."
    }
}
