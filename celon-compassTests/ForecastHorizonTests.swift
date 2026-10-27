//
//  ForecastHorizonTests.swift
//  celon-compassTests
//

import Testing
import Foundation
@testable import celon_compass

struct ForecastHorizonTests {
    private let now = Calendar.current.startOfDay(for: .now)

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: now)!
    }

    @Test func todayIsAvailable() {
        #expect(ForecastHorizon.isAvailable(for: day(0), now: now))
    }

    @Test func fifteenDaysOutIsAvailable() {
        #expect(ForecastHorizon.isAvailable(for: day(15), now: now))
    }

    @Test func sixteenDaysOutIsNotAvailable() {
        #expect(!ForecastHorizon.isAvailable(for: day(16), now: now))
    }

    @Test func pastDatesAreNotAvailable() {
        #expect(!ForecastHorizon.isAvailable(for: day(-1), now: now))
    }
}
