//
//  ForecastHorizon.swift
//  celon-compass
//
//  Open-Meteo's free tier caps daily forecasts at 16 days out. A trip stop dated beyond
//  that window will never have a matching DayForecast entry: tells call sites
//  whether that's "not fetched yet" or "can never be fetched", so the UI can show a
//  distinct neutral state instead of looking identical to a degraded/failed fetch.
//

import Foundation

enum ForecastHorizon {
    static let maximumDaysAhead = 15

    static func isAvailable(for date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        let from = calendar.startOfDay(for: now)
        let to = calendar.startOfDay(for: date)
        guard let days = calendar.dateComponents([.day], from: from, to: to).day else { return false }
        return days >= 0 && days <= maximumDaysAhead
    }
}
