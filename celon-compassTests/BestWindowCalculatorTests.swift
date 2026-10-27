//
//  BestWindowCalculatorTests.swift
//  celon-compassTests
//

import Testing
import Foundation
@testable import celon_compass

struct BestWindowCalculatorTests {
    private let calendar = Calendar.current

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: .now))!
    }

    private func forecast(dayOffset: Int, condition: WeatherCondition, rain: Int) -> DayForecast {
        DayForecast(date: day(dayOffset), high: 30, low: 22, rainProbability: rain, uvIndex: 7, condition: condition)
    }

    @Test func returnsNilForFewerThanTwoDestinations() {
        let forecasts: [UUID: [DayForecast]] = [
            UUID(): [forecast(dayOffset: 0, condition: .clear, rain: 5)]
        ]
        #expect(BestWindowCalculator.bestWindow(forecasts: forecasts) == nil)
    }

    @Test func returnsNilWhenThereIsNoDateOverlap() {
        let forecasts: [UUID: [DayForecast]] = [
            UUID(): [forecast(dayOffset: 0, condition: .clear, rain: 5)],
            UUID(): [forecast(dayOffset: 10, condition: .clear, rain: 5)]
        ]
        #expect(BestWindowCalculator.bestWindow(forecasts: forecasts) == nil)
    }

    @Test func picksTheClearestContiguousWindow() {
        // 7 days, each destination: storm/rain everywhere except days 3-5 which are clear/low-rain.
        func series(badRain: Int) -> [DayForecast] {
            (0..<7).map { offset in
                if (3...5).contains(offset) {
                    return forecast(dayOffset: offset, condition: .clear, rain: 5)
                } else {
                    return forecast(dayOffset: offset, condition: .storm, rain: badRain)
                }
            }
        }
        let forecasts: [UUID: [DayForecast]] = [
            UUID(): series(badRain: 80),
            UUID(): series(badRain: 85)
        ]

        let window = BestWindowCalculator.bestWindow(forecasts: forecasts)
        let expectedDays = Set([3, 4, 5].map { day($0) })

        #expect(window != nil)
        #expect(Set(window!.days) == expectedDays)
        #expect(window!.isAllClear)
    }

    @Test func tieBreaksByLongerWindowThenEarlierStart() {
        
        func series() -> [DayForecast] {
            (0..<4).map { forecast(dayOffset: $0, condition: .cloudy, rain: 20) }
        }
        let forecasts: [UUID: [DayForecast]] = [
            UUID(): series(),
            UUID(): series()
        ]

        let window = BestWindowCalculator.bestWindow(forecasts: forecasts)
        let expectedDays = Set((0..<4).map { day($0) })

        #expect(window != nil)
        #expect(Set(window!.days) == expectedDays)
    }

    @Test func scoreReturnsIdealBandForClearLowRainWindow() {
        let id = UUID()
        let series: [DayForecast] = (0..<5).map { offset in
            forecast(dayOffset: offset, condition: .clear, rain: 5)
        }
        let days = (0..<5).map(day)
        let result = BestWindowCalculator.score(destinationId: id, forecasts: series, over: days)

        #expect(result != nil)
        #expect(result!.score >= Band.idealThreshold)
        #expect(result!.band == .ideal)
    }

    @Test func scoreReturnsFairBandForStormyRainyWindow() {
        let id = UUID()
        let series: [DayForecast] = (0..<4).map { offset in
            forecast(dayOffset: offset, condition: .storm, rain: 90)
        }
        let days = (0..<4).map(day)
        let result = BestWindowCalculator.score(destinationId: id, forecasts: series, over: days)

        #expect(result != nil)
        #expect(result!.band == .fair)
    }

    @Test func scoreIgnoresDaysOutsideTheWindow() {
        let id = UUID()
        let good: [DayForecast] = (0..<3).map { forecast(dayOffset: $0, condition: .clear, rain: 5) }
        let bad: [DayForecast] = (5..<8).map { forecast(dayOffset: $0, condition: .storm, rain: 95) }
        let series = good + bad
        let scopedDays = (0..<3).map(day)

        let result = BestWindowCalculator.score(destinationId: id, forecasts: series, over: scopedDays)

        #expect(result?.evaluatedDayCount == 3)
        #expect(result!.band == .ideal)
    }

    @Test func bandThresholdBoundariesAreInclusiveOnTheLowSide() {
        #expect(Band.of(Band.idealThreshold) == .ideal)
        #expect(Band.of(Band.idealThreshold - 1) == .good)
        #expect(Band.of(Band.goodThreshold) == .good)
        #expect(Band.of(Band.goodThreshold - 1) == .fair)
    }

    @Test func fallsBackToTheLeastBadWindowWhenNothingIsTrulyClear() {
        func series(rain: [Int]) -> [DayForecast] {
            rain.enumerated().map { offset, value in
                forecast(dayOffset: offset, condition: .rain, rain: value)
            }
        }
        let forecasts: [UUID: [DayForecast]] = [
            UUID(): series(rain: [90, 40, 45, 95]),
            UUID(): series(rain: [85, 35, 50, 90])
        ]

        let window = BestWindowCalculator.bestWindow(forecasts: forecasts, minimumWindowLength: 2)

        #expect(window != nil)
        #expect(!window!.isAllClear)
        #expect(Set(window!.days) == Set([1, 2].map { day($0) }))
    }
}
