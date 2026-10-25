//
//  WeatherConditionTests.swift
//  celon-compassTests
//

import Testing
@testable import celon_compass

struct WeatherConditionTests {
    @Test func clearSky() {
        #expect(WeatherCondition.from(wmoCode: 0) == .clear)
    }

    @Test func cloudyBand() {
        #expect(WeatherCondition.from(wmoCode: 1) == .cloudy)
        #expect(WeatherCondition.from(wmoCode: 3) == .cloudy)
        #expect(WeatherCondition.from(wmoCode: 45) == .cloudy)
        #expect(WeatherCondition.from(wmoCode: 48) == .cloudy)
    }

    @Test func rainBand() {
        #expect(WeatherCondition.from(wmoCode: 51) == .rain)
        #expect(WeatherCondition.from(wmoCode: 65) == .rain)
        #expect(WeatherCondition.from(wmoCode: 77) == .rain)
    }

    @Test func stormIsEightyAndAbove() {
        #expect(WeatherCondition.from(wmoCode: 77) == .rain)
        #expect(WeatherCondition.from(wmoCode: 80) == .storm)
        #expect(WeatherCondition.from(wmoCode: 99) == .storm)
    }

    @Test func unknownCodeFallsBackToCloudy() {
        #expect(WeatherCondition.from(wmoCode: -1) == .cloudy)
        #expect(WeatherCondition.from(wmoCode: 4) == .cloudy)
    }
}
