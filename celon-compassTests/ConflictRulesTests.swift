//
//  ConflictRulesTests.swift
//  celon-compassTests
//

import Testing
import Foundation
import CoreData
@testable import celon_compass

@MainActor
struct ConflictRulesTests {
    private var context: NSManagedObjectContext { TestStore.context }

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: .now))!
    }

    private func makeDestination(latitude: Double = 6.9271, longitude: Double = 79.8612) -> Destination {
        let destination = Destination(context: context)
        destination.id = UUID()
        destination.latitude = latitude
        destination.longitude = longitude
        return destination
    }

    private func makeStop(
        date: Date,
        destination: Destination? = nil,
        latitude: Double = 0,
        longitude: Double = 0
    ) -> ItineraryStop {
        let stop = ItineraryStop(context: context)
        stop.id = UUID()
        stop.date = date
        stop.destination = destination
        stop.poiLatitude = latitude
        stop.poiLongitude = longitude
        return stop
    }

    private struct StubRouting: RoutingServicing {
        let duration: TimeInterval
        func estimate(from: Coordinate, to: Coordinate) -> RouteEstimate {
            RouteEstimate(distanceKm: 0, duration: duration)
        }
    }

    //flagStormRisk
    @Test func flagsOnlyStopsWhoseDayIsForecastStorm() {
        let destination = makeDestination()
        guard let destinationID = destination.id else { Issue.record("missing id"); return }

        let stormStop = makeStop(date: day(0), destination: destination)
        let clearStop = makeStop(date: day(1), destination: destination)

        let forecasts: [UUID: [DayForecast]] = [
            destinationID: [
                DayForecast(date: day(0), high: 28, low: 22, rainProbability: 90, uvIndex: 2, condition: .storm),
                DayForecast(date: day(1), high: 30, low: 23, rainProbability: 5, uvIndex: 8, condition: .clear)
            ]
        ]

        let flagged = ConflictRules.flagStormRisk([stormStop, clearStop], forecasts: forecasts)

        #expect(flagged == [stormStop.id!])
    }

    @Test func stormRiskIgnoresStopsWithNoCachedForecast() {
        let destination = makeDestination()
        let stop = makeStop(date: day(0), destination: destination)

        let flagged = ConflictRules.flagStormRisk([stop], forecasts: [:])

        #expect(flagged.isEmpty)
    }

    //flagTravelTime
    @Test func flagsArrivingStopWhenDriveExceedsThresholdOnConsecutiveDays() {
        let far = makeStop(date: day(1), latitude: 6.0, longitude: 80.0)
        let near = makeStop(date: day(0), latitude: 6.9271, longitude: 79.8612)

        let flagged = ConflictRules.flagTravelTime(
            [near, far],
            routing: StubRouting(duration: 5 * 3600),
            maxReasonableDuration: 4 * 3600
        )

        #expect(flagged == [far.id!])
    }

    @Test func doesNotFlagWhenDriveFitsWithinThreshold() {
        let a = makeStop(date: day(0), latitude: 6.9271, longitude: 79.8612)
        let b = makeStop(date: day(1), latitude: 6.0, longitude: 80.0)

        let flagged = ConflictRules.flagTravelTime(
            [a, b],
            routing: StubRouting(duration: 2 * 3600),
            maxReasonableDuration: 4 * 3600
        )

        #expect(flagged.isEmpty)
    }

    @Test func doesNotFlagStopsMoreThanOneDayApart() {
        let a = makeStop(date: day(0), latitude: 6.9271, longitude: 79.8612)
        let b = makeStop(date: day(3), latitude: 6.0, longitude: 80.0)

        let flagged = ConflictRules.flagTravelTime(
            [a, b],
            routing: StubRouting(duration: 10 * 3600),
            maxReasonableDuration: 4 * 3600
        )

        #expect(flagged.isEmpty)
    }

    //sameDayStopIDs (pre-existing rule, unchanged regression check)

    @Test func flagsStopsSharingACalendarDay() {
        let a = makeStop(date: day(0))
        let b = makeStop(date: day(0))
        let c = makeStop(date: day(1))

        let flagged = ConflictRules.sameDayStopIDs([a, b, c])

        #expect(flagged == Set([a.id!, b.id!]))
    }
}
