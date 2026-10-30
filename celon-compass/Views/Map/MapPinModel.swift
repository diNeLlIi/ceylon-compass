//
//  MapPinModel.swift
//  celon-compass
//


import CoreLocation
import Foundation

enum MapPinKind {
    case tripStop(order: Int, date: Date?)
    case visited(rating: Int16, visitDate: Date?)
    case searchResult
}

struct MapPin: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    // nil for stops added from OpenStreetMap gems: no catalog entry, so no weather
    let destination: Destination?
    let kind: MapPinKind
    let forecast: DayForecast?

    var stop: ItineraryStop?
    var visit: VisitRecord?
}

enum MapPinBuilder {
    // Precedence: a destination on the active trip never also renders as visited or as a search result
    static func pins(
        tripStops: [ItineraryStop],
        visits: [VisitRecord],
        searchResult: Destination?,
        forecasts: [UUID: [DayForecast]]
    ) -> [MapPin] {
        var pins: [MapPin] = []
        var claimed: Set<UUID> = []

        for (index, stop) in tripStops.enumerated() {
            if let destinationID = stop.destination?.id { claimed.insert(destinationID) }
            pins.append(
                MapPin(
                    id: stop.id?.uuidString ?? "stop-\(index)",
                    name: stop.poiName ?? "Stop",
                    coordinate: CLLocationCoordinate2D(latitude: stop.poiLatitude, longitude: stop.poiLongitude),
                    destination: stop.destination,
                    kind: .tripStop(order: index + 1, date: stop.date),
                    forecast: forecast(for: stop.destination, on: stop.date, in: forecasts),
                    stop: stop
                )
            )
        }

        for visit in visits {
            guard let destination = visit.destination,
                  let destinationID = destination.id,
                  !claimed.contains(destinationID)
            else { continue }
            claimed.insert(destinationID)
            pins.append(
                MapPin(
                    id: visit.id?.uuidString ?? "visit-\(destinationID.uuidString)",
                    name: destination.name ?? "Visited",
                    coordinate: CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude),
                    destination: destination,
                    kind: .visited(rating: visit.rating, visitDate: visit.visitDate),
                    forecast: forecast(for: destination, on: nil, in: forecasts),
                    visit: visit
                )
            )
        }

        if let searchResult, let destinationID = searchResult.id, !claimed.contains(destinationID) {
            pins.append(
                MapPin(
                    id: "search-\(destinationID.uuidString)",
                    name: searchResult.name ?? "Destination",
                    coordinate: CLLocationCoordinate2D(latitude: searchResult.latitude, longitude: searchResult.longitude),
                    destination: searchResult,
                    kind: .searchResult,
                    forecast: forecast(for: searchResult, on: nil, in: forecasts)
                )
            )
        }

        return pins
    }

    // Resolved against the stop's own date. Using the first available day would show
    // today's weather for a stop scheduled a week out.
    static func forecast(
        for destination: Destination?,
        on date: Date?,
        in forecasts: [UUID: [DayForecast]]
    ) -> DayForecast? {
        guard let id = destination?.id, let days = forecasts[id] else { return nil }
        guard let date else { return days.first }
        return days.first { Calendar.current.isDate($0.date, inSameDayAs: date) } ?? days.first
    }

    static func sortedStops(of trip: Itinerary?) -> [ItineraryStop] {
        guard let trip else { return [] }
        return ((trip.stops as? Set<ItineraryStop>) ?? [])
            .sorted {
                if $0.date != $1.date { return ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
                return $0.sortOrder < $1.sortOrder
            }
    }
}
