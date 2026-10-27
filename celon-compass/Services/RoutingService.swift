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

    
    private let roadFactor: Double
    private let averageSpeedKmh: Double

    init(roadFactor: Double = 1.2, averageSpeedKmh: Double = 54) {
        self.roadFactor = roadFactor
        self.averageSpeedKmh = averageSpeedKmh
    }

    func estimate(from: Coordinate, to: Coordinate) -> RouteEstimate {
        let distanceKm = Haversine.distanceKm(from: from, to: to) * roadFactor
        let hours = distanceKm / averageSpeedKmh
        return RouteEstimate(distanceKm: distanceKm, duration: hours * 3600)
    }
}
