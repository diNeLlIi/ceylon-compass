//
//  HourForecast.swift
//  celon-compass
//
//

import Foundation

struct HourForecast: Codable, Identifiable, Equatable {
    var id: Date { time }
    let time: Date
    let temperature: Double
    let rainProbability: Int
    let condition: WeatherCondition
}

enum WallClock {
    // Open-Meteo's timezone=auto values are already local to the destination
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    static func hourLabel(_ date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
