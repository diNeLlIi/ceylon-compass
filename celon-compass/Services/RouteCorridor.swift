//
//  RouteCorridor.swift
//  celon-compass
//

import Foundation

struct Coordinate: Equatable {
    let latitude: Double
    let longitude: Double
}


enum DefaultOrigin {
    static let name = "Colombo"
    static let coordinate = Coordinate(latitude: 6.9271, longitude: 79.8612)
}

enum Haversine {
    private static let earthRadiusKm = 6371.0

    static func distanceKm(from: Coordinate, to: Coordinate) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusKm * c
    }
}

enum RouteCorridor {

    static func offRouteDistanceKm(point: Coordinate, from: Coordinate, to: Coordinate) -> Double {
        min(Haversine.distanceKm(from: point, to: from), Haversine.distanceKm(from: point, to: to))
    }

    static func isWithin(radiusKm: Double, point: Coordinate, from: Coordinate, to: Coordinate) -> Bool {
        offRouteDistanceKm(point: point, from: from, to: to) <= radiusKm
    }
}

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
}
