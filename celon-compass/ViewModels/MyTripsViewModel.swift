//
//  MyTripsViewModel.swift
//  celon-compass
//

import Combine
import Foundation

@MainActor
final class MyTripsViewModel: ObservableObject {
    @Published private(set) var forecasts: [UUID: [DayForecast]] = [:]

    private let weatherService: WeatherServicing

    init(weatherService: WeatherServicing = WeatherService()) {
        self.weatherService = weatherService
    }

    func loadForecasts(for trips: [Itinerary]) async {
        let allDestinations = trips
            .flatMap { ($0.stops as? Set<ItineraryStop>) ?? [] }
            .compactMap(\.destination)

        var seenIDs = Set<UUID>()
        let uniqueDestinations = allDestinations.filter { destination in
            guard let id = destination.id else { return false }
            return seenIDs.insert(id).inserted
        }
        guard !uniqueDestinations.isEmpty else { return }
        forecasts = (try? await weatherService.forecasts(for: uniqueDestinations)) ?? [:]
    }

    
    func forecast(for stop: ItineraryStop) -> DayForecast? {
        guard let destination = stop.destination, let id = destination.id, let date = stop.date else { return nil }
        return forecasts[id]?.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}
