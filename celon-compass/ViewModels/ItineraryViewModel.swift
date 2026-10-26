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

    func banner(from stops: [ItineraryStop]) -> Banner? {
        let sections = daySections(from: stops)
        guard let section = sections.first(where: { section in
            !dismissedConflictDates.contains(section.date) && section.stops.contains { $0.hasConflict }
        }) else { return nil }

        let conflicted = section.stops.filter(\.hasConflict)
        guard conflicted.count >= 2, let stopToMove = conflicted.last else { return nil }

        let names = conflicted.compactMap(\.poiName)
        let dayText = section.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        var message = "\(names.joined(separator: " and ")) are both booked"
        if let worst = conflicted.compactMap(forecast(for:)).max(by: { $0.rainProbability < $1.rainProbability }),
           worst.rainProbability >= 50 {
            message += ", and \(stopToMove.poiName ?? "one stop") has \(worst.rainProbability)% rain"
        }
        message += "."

        let lastDate = stops.compactMap(\.date).max() ?? section.date
        let suggestedDate = Calendar.current.date(byAdding: .day, value: 1, to: lastDate) ?? lastDate
        let suggestedForecast = stopToMove.destination.flatMap { destination -> DayForecast? in
            guard let id = destination.id else { return nil }
            return forecasts[id]?.first { Calendar.current.isDate($0.date, inSameDayAs: suggestedDate) }
        }

        return Banner(
            title: "\(dayText) is overloaded",
            message: message,
            date: section.date,
            stopToMove: stopToMove,
            suggestedDate: suggestedDate,
            suggestedDateIsClear: suggestedForecast?.condition == .clear
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
