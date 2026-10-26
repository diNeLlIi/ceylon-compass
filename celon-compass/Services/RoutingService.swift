//
//  RoutingService.swift
//  celon-compass
//

import Foundation

struct RouteEstimate: Equatable {
    let distanceKm: Double
    let duration: TimeInterval
}

protocol RoutingServicing {
    func estimate(from: Coordinate, to: Coordinate) -> RouteEstimate
}


struct HaversineRoutingService: RoutingServicing {

    private let averageSpeedKmh: Double

    init(averageSpeedKmh: Double = 45) {
        self.averageSpeedKmh = averageSpeedKmh
    }

    func estimate(from: Coordinate, to: Coordinate) -> RouteEstimate {
        let distanceKm = Haversine.distanceKm(from: from, to: to)
        let hours = distanceKm / averageSpeedKmh
        return RouteEstimate(distanceKm: distanceKm, duration: hours * 3600)
    }
}
