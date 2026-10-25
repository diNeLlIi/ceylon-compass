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
        // Every day identical badness across a 4-day overlap - every window ties on score;
        // the longest window (the full 4 days, starting at day 0) must win.
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
