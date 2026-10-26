//
//  DestinationDetailViewModel.swift
//  celon-compass
//

import Combine
import Foundation

@MainActor
final class DestinationDetailViewModel: ObservableObject {
    let destination: Destination
    @Published private(set) var forecasts: [DayForecast]
    let favouritesStore: FavouritesStore

    init(destination: Destination, forecasts: [DayForecast], favouritesStore: FavouritesStore = .shared) {
        self.destination = destination
        self.forecasts = forecasts
        self.favouritesStore = favouritesStore
    }

    private var destinationId: UUID { destination.id ?? UUID() }

    var isFavourite: Bool { favouritesStore.isFavourite(destinationId) }

    func toggleFavourite() {
        favouritesStore.toggle(destinationId)
    }

    var coordinate: Coordinate {
        Coordinate(latitude: destination.latitude, longitude: destination.longitude)
    }


    var bestWindow: BestWindow? {
        guard !forecasts.isEmpty else { return nil }
        return BestWindowCalculator.bestWindow(
            forecasts: [destinationId: forecasts],
            minimumDestinations: 1
        )
    }
}
