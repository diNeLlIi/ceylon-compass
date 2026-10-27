//
//  ItineraryViewModel.swift
//  celon-compass
//
//

import Combine
import CoreData
import Foundation
import SwiftUI

@MainActor
final class ItineraryViewModel: ObservableObject {
    struct DaySection: Identifiable {
        let date: Date
        let stops: [ItineraryStop]
        var id: Date { date }
    }

    let trip: Itinerary
    @Published private(set) var forecasts: [UUID: [DayForecast]] = [:]
    @Published private var dismissedConflictDates: Set<Date> = []
    @Published var errorMessage: String?

    private let repository: TripRepository
    private let weatherService: WeatherServicing

    init(trip: Itinerary, context: NSManagedObjectContext, weatherService: WeatherServicing = WeatherService()) {
        self.trip = trip
        self.repository = TripRepository(context: context)
        self.weatherService = weatherService
    }

    func daySections(from stops: [ItineraryStop]) -> [DaySection] {
        let grouped = Dictionary(grouping: stops) { Calendar.current.startOfDay(for: $0.date ?? .distantPast) }
        return grouped.keys.sorted().map { day in
            DaySection(date: day, stops: (grouped[day] ?? []).sorted { $0.sortOrder < $1.sortOrder })
        }
    }

    func forecast(for stop: ItineraryStop) -> DayForecast? {
        guard let destination = stop.destination, let id = destination.id, let date = stop.date else { return nil }
        return forecasts[id]?.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func loadForecasts(for stops: [ItineraryStop]) async {
        let destinations = stops.compactMap(\.destination)
        var seenIDs = Set<UUID>()
        let uniqueDestinations = destinations.filter { destination in
            guard let id = destination.id else { return false }
            return seenIDs.insert(id).inserted
        }
        guard !uniqueDestinations.isEmpty else { return }
        forecasts = (try? await weatherService.forecasts(for: uniqueDestinations)) ?? [:]
    }

    struct Banner {
        let title: String
        let message: String
        let date: Date
        let stopToMove: ItineraryStop
        let suggestedDate: Date
        let suggestedDateIsClear: Bool
    }

    struct DoubleBookedNotice {
        let title: String
        let message: String
        let date: Date
        let stopToMove: ItineraryStop
        let suggestedDate: Date
    }

    private func suggestedDate(after stops: [ItineraryStop], from day: Date) -> Date {
        let lastDate = stops.compactMap(\.date).max() ?? day
        return Calendar.current.date(byAdding: .day, value: 1, to: lastDate) ?? lastDate
    }

    
    private static let urgentConflictPriority: [String: Int] = [
        "stormRisk": 0,
        "travelTime": 1
    ]

    func attentionBanner(from stops: [ItineraryStop]) -> Banner? {
        let conflicted = stops.filter { stop in
            guard stop.hasConflict,
                  let kind = stop.conflictKind, Self.urgentConflictPriority[kind] != nil,
                  let date = stop.date
            else { return false }
            return !dismissedConflictDates.contains(Calendar.current.startOfDay(for: date))
        }
        guard let stopToMove = conflicted.min(by: {
            let lhs = Self.urgentConflictPriority[$0.conflictKind ?? ""] ?? .max
            let rhs = Self.urgentConflictPriority[$1.conflictKind ?? ""] ?? .max
            return lhs < rhs
        }) else { return nil }

        let day = Calendar.current.startOfDay(for: stopToMove.date ?? .distantPast)
        let dayText = day.formatted(.dateTime.weekday(.wide).day().month(.wide))

        let title: String
        let message: String

        if stopToMove.conflictKind == "stormRisk" {
            title = "\(dayText) has storm risk"
            let name = stopToMove.poiName ?? "This stop"
            if let destinationID = stopToMove.destination?.id,
               let dayForecast = forecasts[destinationID]?.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
                message = "\(name) is forecast \(dayForecast.rainProbability)% rain with storm conditions."
            } else {
                message = "\(name) is forecast storm conditions."
            }
        } else {
            title = "\(dayText) has a long drive"
            message = "The drive to \(stopToMove.poiName ?? "this stop") takes longer than the schedule allows between these two days."
        }

        let suggested = suggestedDate(after: stops, from: day)
        let suggestedForecast = stopToMove.destination.flatMap { destination -> DayForecast? in
            guard let id = destination.id else { return nil }
            return forecasts[id]?.first { Calendar.current.isDate($0.date, inSameDayAs: suggested) }
        }

        return Banner(
            title: title,
            message: message,
            date: day,
            stopToMove: stopToMove,
            suggestedDate: suggested,
            suggestedDateIsClear: suggestedForecast?.condition == .clear
        )
    }

    // The compact "Fix" notice — a same-day scheduling clash, not a hazard, so there's
    // no "Keep" option: tapping Fix resolves it outright instead of asking the user to
    // confirm they're happy to live with it
    func doubleBookedNotice(from stops: [ItineraryStop]) -> DoubleBookedNotice? {
        let sections = daySections(from: stops)
        guard let section = sections.first(where: { section in
            !dismissedConflictDates.contains(section.date) && section.stops.contains { $0.conflictKind == "doubleBooked" }
        }) else { return nil }

        let conflicted = section.stops.filter { $0.conflictKind == "doubleBooked" }
        guard conflicted.count >= 2, let stopToMove = conflicted.last else { return nil }

        let names = conflicted.compactMap(\.poiName)
        let monthDay = section.date.formatted(.dateTime.month(.abbreviated).day())
        let weekday = section.date.formatted(.dateTime.weekday(.wide))

        return DoubleBookedNotice(
            title: "Two stops on \(monthDay)",
            message: "\(names.joined(separator: " and ")) are both scheduled for \(weekday).",
            date: section.date,
            stopToMove: stopToMove,
            suggestedDate: suggestedDate(after: stops, from: section.date)
        )
    }

    func resolveConflict(_ banner: Banner) {
        do {
            try repository.moveStop(banner.stopToMove, to: banner.suggestedDate)
            try repository.recomputeConflicts(for: trip)
        } catch {
            errorMessage = "Couldn't move that stop. Try again."
        }
    }

    func keep(_ banner: Banner) {
        dismissedConflictDates.insert(banner.date)
    }

    func resolveDoubleBooked(_ notice: DoubleBookedNotice) {
        do {
            try repository.moveStop(notice.stopToMove, to: notice.suggestedDate)
            try repository.recomputeConflicts(for: trip)
        } catch {
            errorMessage = "Couldn't move that stop. Try again."
        }
    }

    func reorder(day: DaySection, from source: IndexSet, to destination: Int) {
        var stops = day.stops
        stops.move(fromOffsets: source, toOffset: destination)
        do {
            try repository.reorder(stops)
        } catch {
            errorMessage = "Couldn't reorder stops."
        }
    }

    func deleteStop(_ stop: ItineraryStop) {
        do {
            try repository.deleteStop(stop)
            try repository.recomputeConflicts(for: trip)
        } catch {
            errorMessage = "Couldn't remove that stop."
        }
    }
}
