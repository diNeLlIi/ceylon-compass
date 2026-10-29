//
//  ActiveTripResolver.swift
//  celon-compass
//
//  which trip is relevant right now logic for the map, geofencing,
//  Add to Trip, and App Intents: all need the same active/upcoming notion

import Foundation

enum ActiveTripResolver {
    static func activeOrUpcoming(_ trips: [Itinerary], now: Date = .now, calendar: Calendar = .current) -> [Itinerary] {
        trips.filter { trip in
            guard let endDate = trip.endDate else { return true }
            return endDate >= calendar.startOfDay(for: now)
        }
    }

    // The single trip most relevant right now: the next  active/upcoming trip
    static func current(_ trips: [Itinerary], now: Date = .now, calendar: Calendar = .current) -> Itinerary? {
        activeOrUpcoming(trips, now: now, calendar: calendar)
            .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
            .first
    }
}
