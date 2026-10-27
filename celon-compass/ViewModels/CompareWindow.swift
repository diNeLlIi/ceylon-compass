//
//  CompareWindow.swift
//  celon-compass
//
//  Time range selection for the Compare destinations screen
//

import Foundation

enum CompareWindow: Equatable, Hashable {
    case next5
    case next14
    case custom(start: Date, end: Date)

    var title: String {
        switch self {
        case .next5: return "Next 5 days"
        case .next14: return "2 weeks"
        case .custom: return "Custom"
        }
    }

    // Ordered list of day-start dates inside the window, clamped to the
    // Open-Meteo horizon so a request can't ask for days it can never answer
    func days(now: Date = .now, calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: now)
        switch self {
        case .next5:
            return offsets(from: start, count: 5, calendar: calendar)
        case .next14:
            return offsets(from: start, count: 14, calendar: calendar)
        case .custom(let s, let e):
            let anchor = calendar.startOfDay(for: s)
            let last = calendar.startOfDay(for: e)
            guard let span = calendar.dateComponents([.day], from: anchor, to: last).day, span >= 0 else {
                return [anchor]
            }
            return offsets(from: anchor, count: span + 1, calendar: calendar)
                .filter { ForecastHorizon.isAvailable(for: $0, now: now, calendar: calendar) }
        }
    }

    private func offsets(from start: Date, count: Int, calendar: Calendar) -> [Date] {
        (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
            .filter { ForecastHorizon.isAvailable(for: $0) }
    }
}
