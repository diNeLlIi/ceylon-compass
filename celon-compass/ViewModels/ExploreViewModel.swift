//
//  ExploreViewModel.swift
//  celon-compass
//

import Combine
internal import Foundation

@MainActor
final class ExploreViewModel: ObservableObject {
    @Published private(set) var destinations: [Destination] = []
    @Published private(set) var forecasts: [UUID: [DayForecast]] = [:]
    @Published var searchText = ""
    @Published var selectedCategory: DestinationCategory = .all
    @Published private(set) var isLoading = false
    @Published private(set) var loadErrorMessage: String?
    @Published private(set) var weatherDegraded = false

    private let catalogService: CatalogServiceProtocol
    private let weatherService: WeatherServicing

    init(catalogService: CatalogServiceProtocol = CatalogService(), weatherService: WeatherServicing = WeatherService()) {
        self.catalogService = catalogService
        self.weatherService = weatherService
    }

    var filteredDestinations: [Destination] {
        destinations.filter { destination in
            selectedCategory.matches(destination.category)
                && (searchText.isEmpty || (destination.name ?? "").localizedCaseInsensitiveContains(searchText))
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            destinations = try await catalogService.fetchDestinations()
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load destinations right now."
            return
        }
        await fetchWeather()
    }

    // pull to refresh: weather only
    func refresh() async {
        await fetchWeather()
    }

    private func fetchWeather() async {
        do {
            forecasts = try await weatherService.forecasts(for: destinations)
            weatherDegraded = false
        } catch {
            weatherDegraded = true
        }
    }
}
