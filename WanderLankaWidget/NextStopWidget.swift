//
//  NextStopWidget.swift
//  WanderLankaWidget
//

import SwiftUI
import WidgetKit

struct NextStopEntry: TimelineEntry {
    let date: Date
    let stops: [UpcomingStop]
    // Distinct from "no stops": the redacted preview the system renders before real
    // data exists, which must never show the "no trips" copy.
    let isPlaceholder: Bool

    var next: UpcomingStop? { stops.first }
}

struct NextStopProvider: TimelineProvider {

    func placeholder(in context: Context) -> NextStopEntry {
        NextStopEntry(date: .now, stops: [.preview], isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextStopEntry) -> Void) {
        // The gallery preview has no access to the user's real trips, so it gets sample
        // data rather than an empty state that would make the widget look broken.
        if context.isPreview {
            completion(NextStopEntry(date: .now, stops: [.preview], isPlaceholder: true))
        } else {
            completion(NextStopEntry(date: .now, stops: WidgetTripStore.upcomingStops(), isPlaceholder: false))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextStopEntry>) -> Void) {
        let now = Date()
        let stops = WidgetTripStore.upcomingStops()
        let calendar = Calendar.current

        // One entry now, then one at the start of each remaining trip day, so the widget
        // rolls over to the next stop by itself without waiting for a refresh budget.
        var entries = [NextStopEntry(date: now, stops: stops, isPlaceholder: false)]
        let futureDays = Set(stops.map { calendar.startOfDay(for: $0.date) })
            .filter { $0 > now }
            .sorted()

        for day in futureDays {
            let remaining = stops.filter { calendar.startOfDay(for: $0.date) >= day }
            entries.append(NextStopEntry(date: day, stops: remaining, isPlaceholder: false))
        }

        // Even with no stops the widget must wake after midnight, or a trip added later
        // today would not appear until the system happened to refresh it.
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(nextMidnight)))
    }
}

struct NextStopWidget: Widget {
    private let kind = "NextStopWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextStopProvider()) { entry in
            NextStopEntryView(entry: entry)
                .containerBackground(AppBrand.canvas, for: .widget)
        }
        .configurationDisplayName("Next Stop")
        .description("Your next stop and its forecast.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

extension UpcomingStop {
    static let preview = UpcomingStop(
        id: UUID(),
        tripID: nil,
        name: "Sigiriya",
        date: .now,
        conditionSymbol: "sun.max.fill",
        conditionLabel: "Clear",
        high: 31,
        isGem: false
    )
}
