//
//  ShowItineraryIntent.swift
//  celon-compass
//
//  Parameterised intent: pick a trip, the app opens on that itinerary.
//

import AppIntents
import Foundation

struct ShowItineraryIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Itinerary"
    static var description = IntentDescription("Opens one of your trips.")

    // Unlike CheckWeather and NextStop, which answer out loud, this one's whole purpose
    // is to put a screen in front of the user.
    static var openAppWhenRun = true

    @Parameter(title: "Trip")
    var trip: TripEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$trip)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: trip.id) else {
            return .result()
        }
        // Routed through the same deep link the widget uses, so there is one way into
        // a trip from outside the app rather than two that can drift apart.
        DeepLinkInbox.shared.pending = .trip(id)
        return .result()
    }
}
