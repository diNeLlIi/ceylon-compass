//
//  PlanTripViewModel.swift
//  celon-compass
//

import Combine
import CoreData
import Foundation

@MainActor
final class PlanTripViewModel: ObservableObject {
    let destination: Destination
    let origin = DefaultOrigin.coordinate
    let originName = DefaultOrigin.name

    @Published private(set) var candidatePOIs: [POI] = []
    @Published private(set) var forecasts: [UUID: [DayForecast]] = [:]
    @Published private(set) var selectedPOIIDs: Set<String> = []
    @Published private(set) var committedRadiusKm: Double
    @Published private(set) var createdTrip: Itinerary?
    @Published private(set) var errorMessage: String?

    private let weatherService: WeatherServicing
    private let routingService: RoutingServicing
    private let defaultRadiusKm: Double = 25

    init(
        destination: Destination,
        weatherService: WeatherServicing = WeatherService(),
        routingService: RoutingServicing = HaversineRoutingService()
    ) {
        self.destination = destination
        self.weatherService = weatherService
        self.routingService = routingService
        self.committedRadiusKm = defaultRadiusKm
    }

    var destinationCoordinate: Coordinate {
        Coordinate(latitude: destination.latitude, longitude: destination.longitude)
    }

    var routeEstimate: RouteEstimate {
        routingService.estimate(from: origin, to: destinationCoordinate)
    }

    // First stop date, used for the header's date badge and as the anchor for
    // every stop's assigned date.
    var tripStartDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    }

    var stopsWithinRadius: [POI] {
        candidatePOIs.filter {
            RouteCorridor.isWithin(radiusKm: committedRadiusKm, point: $0.coordinate, from: origin, to: destinationCoordinate)
        }
    }

    var selectedStops: [POI] {
        selectedPOIIDs.compactMap { id in stopsWithinRadius.first { $0.id == id } }
    }

    func forecast(for poi: POI) -> DayForecast? {
        guard let destination = poi.destination, let id = destination.id else { return nil }
        return forecasts[id]?.first
    }

    func isSelected(_ poi: POI) -> Bool {
        selectedPOIIDs.contains(poi.id)
    }

    func toggle(_ poi: POI) {
        if selectedPOIIDs.contains(poi.id) {
            selectedPOIIDs.remove(poi.id)
        } else {
            selectedPOIIDs.insert(poi.id)
        }
    }

    func commitRadius(_ radiusKm: Double) {
        committedRadiusKm = radiusKm
    }

    func dismissError() {
        errorMessage = nil
    }

    func load() async {
        
        let allDestinations = CoreDataSync.fetchAll()
        candidatePOIs = allDestinations
            .filter { $0.id != destination.id }
            .map { POI(destination: $0) }

        do {
            var forDestinations = candidatePOIs.compactMap(\.destination)
            forDestinations.append(destination)
            forecasts = try await weatherService.forecasts(for: forDestinations)
        } catch {
            forecasts = [:]
        }
    }

    // Writes the fixed Colombo origin into the trip, adds every selected stop
    // (one calendar day apart, starting tomorrow) plus the destination itself
    // as the final stop, then recomputes conflicts once.
    @discardableResult
    func createItinerary(context: NSManagedObjectContext) -> Itinerary? {
        let repository = TripRepository(context: context)
        let orderedStops = selectedStops + [POI(destination: destination)]
        let calendar = Calendar.current

        do {
            let trip = try repository.createTrip(title: destination.name ?? "Untitled trip")
            trip.originName = originName
            trip.originLat = origin.latitude
            trip.originLon = origin.longitude

            var stopDates: [Date] = []
            for (index, poi) in orderedStops.enumerated() {
                let date = calendar.date(byAdding: .day, value: index, to: tripStartDate) ?? tripStartDate
                stopDates.append(date)
                try repository.addStop(to: trip, poi: poi, date: date, sortIndex: Int16(index))
            }
            trip.startDate = stopDates.min() ?? tripStartDate
            trip.endDate = stopDates.max() ?? tripStartDate

            try repository.recomputeConflicts(for: trip)
            createdTrip = trip
            return trip
        } catch {
            errorMessage = "Couldn't create the trip. Try again."
            return nil
        }
    }
}
