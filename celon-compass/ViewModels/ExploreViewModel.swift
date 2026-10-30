//
//  ExploreViewModel.swift
//  celon-compass
//

import Combine
import Foundation

@MainActor
final class ExploreViewModel: ObservableObject {
    @Published private(set) var destinations: [Destination] = []
    @Published private(set) var forecasts: [UUID: [DayForecast]] = [:]
    @Published var searchText = ""
    @Published var selectedCategory: DestinationCategory = .all
    // Session-only on purpose: a province left selected from last launch would look like
    // a missing catalog rather than an active filter.
    @Published var selectedProvince: Province?
    @Published private(set) var isLoading = false
    @Published private(set) var loadErrorMessage: String?
    @Published private(set) var weatherDegraded = false

    private let catalogService: CatalogServiceProtocol
    private let weatherService: WeatherServicing
    let favouritesStore: FavouritesStore

    init(
        catalogService: CatalogServiceProtocol = CatalogService(),
        weatherService: WeatherServicing = WeatherService(),
        favouritesStore: FavouritesStore = .shared
    ) {
        self.catalogService = catalogService
        self.weatherService = weatherService
        self.favouritesStore = favouritesStore
    }

    var filteredDestinations: [Destination] {
        Self.filter(
            destinations,
            category: selectedCategory,
            province: selectedProvince,
            searchText: searchText
        )
    }

    // Pure and static so the three-way AND can be tested without a view model, a catalog
    // fetch, or a running UI. The one and only filtered list — no second array.
    static func filter(
        _ destinations: [Destination],
        category: DestinationCategory,
        province: Province?,
        searchText: String
    ) -> [Destination] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return destinations.filter { destination in
            category.matches(destination.category)
                && (province.map { $0.matches(destination.province) } ?? true)
                && (query.isEmpty || (destination.name ?? "").localizedCaseInsensitiveContains(query))
        }
    }

    var hasActiveFilters: Bool {
        selectedCategory != .all
            || selectedProvince != nil
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func clearFilters() {
        selectedCategory = .all
        selectedProvince = nil
        searchText = ""
    }

    // Counted against the category and search already in force, so the menu tells the user
    // what each province would actually yield rather than its catalog total.
    func destinationCount(for province: Province) -> Int {
        Self.filter(
            destinations,
            category: selectedCategory,
            province: province,
            searchText: searchText
        ).count
    }

    var emptyStateMessage: String {
        let provinceText = selectedProvince.map { " in \($0.displayName)" } ?? ""
        let categoryText = selectedCategory == .all ? "" : " for \(selectedCategory.rawValue)"
        if provinceText.isEmpty && categoryText.isEmpty {
            return "No destinations match your search."
        }
        return "No destinations\(provinceText)\(categoryText)."
    }

    var favouriteDestinations: [Destination] {
        destinations.filter { destination in
            guard let id = destination.id else { return false }
            return favouritesStore.isFavourite(id)
        }
    }

    // The destination with the best weather
    var todaysPick: Destination? {
        destinations
            .filter { forecast(for: $0) != nil }
            .min { weatherScore(for: $0) < weatherScore(for: $1) }
    }

    // Top destinations sorted by best weather
    var bestWeatherDestinations: [Destination] {
        destinations
            .filter { $0.id != todaysPick?.id && forecast(for: $0) != nil }
            .sorted { weatherScore(for: $0) < weatherScore(for: $1) }
    }

    func forecast(for destination: Destination) -> DayForecast? {
        guard let id = destination.id else { return nil }
        return forecasts[id]?.first
    }

    func weatherScore(for destination: Destination) -> Double {
        guard let forecast = forecast(for: destination) else { return .greatestFiniteMagnitude }
        let conditionPenalty: Double
        switch forecast.condition {
        case .clear: conditionPenalty = 0
        case .cloudy: conditionPenalty = 10
        case .rain: conditionPenalty = 35
        case .storm: conditionPenalty = 60
        }
        return Double(forecast.rainProbability) + conditionPenalty
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
