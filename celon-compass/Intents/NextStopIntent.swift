//
//  NextStopIntent.swift
//  celon-compass
//

import AppIntents
import CoreData
import Foundation

struct NextStopIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Stop"
    static var description = IntentDescription("Reads the next stop on your active trip.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = PersistenceController.shared.container.viewContext
        let request = Itinerary.fetchRequest()
        let trips = (try? context.fetch(request)) ?? []

        guard let trip = ActiveTripResolver.current(trips) else {
            return .result(dialog: "You don't have an active trip right now.")
        }

        let today = Calendar.current.startOfDay(for: .now)
        let upcoming = ((trip.stops as? Set<ItineraryStop>) ?? [])
            .filter { ($0.date ?? .distantPast) >= today }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }

        guard let next = upcoming.first else {
            return .result(dialog: "\(trip.title ?? "Your trip") doesn't have any upcoming stops.")
        }

        let dateText = next.date?.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) ?? ""
        return .result(dialog: "Your next stop is \(next.poiName ?? "a stop") on \(dateText).")
    }
}
