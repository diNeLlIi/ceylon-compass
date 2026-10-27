//
//  ConflictRules.swift
//  celon-compass
//
//
//

import Foundation

enum ConflictRules {

    // Flags every stop that shares a calendar day with another stop in the same itinerary
    static func sameDayStopIDs(_ stops: [ItineraryStop], calendar: Calendar = .current) -> Set<UUID> {
        var byDay: [DateComponents: [UUID]] = [:]
        for stop in stops {
            guard let id = stop.id, let date = stop.date else { continue }
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            byDay[components, default: []].append(id)
        }
        return byDay.values
            .filter { $0.count > 1 }
            .reduce(into: Set<UUID>()) { $0.formUnion($1) }
    }

    // Flags a stop whose scheduled day is forecast storm conditions at its destination
    static func flagStormRisk(
        _ stops: [ItineraryStop],
        forecasts: [UUID: [DayForecast]],
        calendar: Calendar = .current
    ) -> Set<UUID> {
        var flagged: Set<UUID> = []
        for stop in stops {
            guard let id = stop.id,
                  let destinationID = stop.destination?.id,
                  let date = stop.date,
                  let dayForecast = forecasts[destinationID]?.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
            else { continue }
            if dayForecast.condition == .storm {
                flagged.insert(id)
            }
        }
        return flagged
    }

    // Flags the arriving stop of a same or next day pair whose estimated drive time exceeds
    // what a single day realistically allows
    static func flagTravelTime(
        _ stops: [ItineraryStop],
        routing: RoutingServicing,
        maxReasonableDuration: TimeInterval = 4 * 3600,
        calendar: Calendar = .current
    ) -> Set<UUID> {
        let ordered = stops
            .filter { $0.date != nil }
            .sorted { $0.date! < $1.date! }
        guard ordered.count > 1 else { return [] }

        var flagged: Set<UUID> = []
        for (previous, current) in zip(ordered, ordered.dropFirst()) {
            guard let previousDate = previous.date,
                  let currentDate = current.date,
                  let dayGap = calendar.dateComponents([.day], from: previousDate, to: currentDate).day,
                  dayGap <= 1,
                  let id = current.id
            else { continue }

            let from = Coordinate(latitude: previous.poiLatitude, longitude: previous.poiLongitude)
            let to = Coordinate(latitude: current.poiLatitude, longitude: current.poiLongitude)
            if routing.estimate(from: from, to: to).duration > maxReasonableDuration {
                flagged.insert(id)
            }
        }
        return flagged
    }
}
