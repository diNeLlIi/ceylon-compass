//
//  CeylonShortcuts.swift
//  celon-compass
//
//  Every phrase must contain \(.applicationName) or it silently fails to register
//

import AppIntents

struct CeylonShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckWeatherIntent(),
            phrases: [
                "Check weather in \(.applicationName)",
                "What's the weather for my trip in \(.applicationName)"
            ],
            shortTitle: "Check Weather",
            systemImageName: "cloud.sun.fill"
        )
        AppShortcut(
            intent: ShowItineraryIntent(),
            phrases: [
                "Show my itinerary in \(.applicationName)",
                "Open my trip in \(.applicationName)"
            ],
            shortTitle: "Show Itinerary",
            systemImageName: "list.bullet.rectangle"
        )
        // Kept as an extra alongside Show Itinerary: this one answers out loud without
        // opening anything, which is the useful shape while driving.
        AppShortcut(
            intent: NextStopIntent(),
            phrases: [
                "What's my next stop in \(.applicationName)",
                "Where am I headed next in \(.applicationName)"
            ],
            shortTitle: "Next Stop",
            systemImageName: "mappin.and.ellipse"
        )
        AppShortcut(
            intent: AddToTripIntent(),
            phrases: [
                "Add a stop to my trip in \(.applicationName)"
            ],
            shortTitle: "Add to Trip",
            systemImageName: "plus.circle.fill"
        )
    }
}
