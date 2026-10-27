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

    static func samplePoints(from: Coordinate, to: Coordinate, count: Int = 5) -> [Coordinate] {
        guard count > 1 else { return [from, to] }
        return (0..<count).map { index in
            let t = Double(index) / Double(count - 1)
            return Coordinate(
                latitude: from.latitude + (to.latitude - from.latitude) * t,
                longitude: from.longitude + (to.longitude - from.longitude) * t
            )
        }
    }
}
