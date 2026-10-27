//
//  RoutingServiceTests.swift
//  celon-compassTests
//

import Testing
import Foundation
@testable import celon_compass

struct RoutingServiceTests {
    // Colombo -> Mirissa,calibration target: ~152 km / ~2h50m.
    @Test func matchesCalibrationTargetForColomboToMirissa() {
        let colombo = Coordinate(latitude: 6.9271, longitude: 79.8612)
        let mirissa = Coordinate(latitude: 5.9483, longitude: 80.4589)

        let estimate = HaversineRoutingService().estimate(from: colombo, to: mirissa)

        #expect((145...160).contains(estimate.distanceKm))
        let hours = estimate.duration / 3600
        #expect((2.6...3.0).contains(hours))
    }

    @Test func roadFactorInflatesStraightLineDistance() {
        let a = Coordinate(latitude: 0, longitude: 0)
        let b = Coordinate(latitude: 0, longitude: 1)

        let straightLine = Haversine.distanceKm(from: a, to: b)
        let estimate = HaversineRoutingService(roadFactor: 1.2, averageSpeedKmh: 54).estimate(from: a, to: b)

        #expect(estimate.distanceKm > straightLine)
    }
}
