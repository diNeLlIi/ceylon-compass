//
//  BestWindowCalculator.swift
//  celon-compass
//
//
//

import Foundation

struct BestWindow: Equatable {
    let days: [Date]   
    let score: Double
    let isAllClear: Bool
}

enum BestWindowCalculator {
    private static func conditionPenalty(_ condition: WeatherCondition) -> Double {
        switch condition {
        case .clear: return 0
        case .cloudy: return 10
        case .rain: return 35
        case .storm: return 60
        }
    }

    static func bestWindow(
        forecasts: [UUID: [DayForecast]],
        minimumWindowLength: Int = 2,
        minimumDestinations: Int = 2
    ) -> BestWindow? {
        guard forecasts.count >= minimumDestinations else { return nil }

        // Sorted intersection of dates present in every destination's forecasts.
        let calendar = Calendar.current
        var dateSets: [Set<DateComponents>] = []
        var forecastsByDay: [UUID: [DateComponents: DayForecast]] = [:]
        for (id, dayForecasts) in forecasts {
            var byDay: [DateComponents: DayForecast] = [:]
            var days: Set<DateComponents> = []
            for forecast in dayForecasts {
                let components = calendar.dateComponents([.year, .month, .day], from: forecast.date)
                byDay[components] = forecast
                days.insert(components)
            }
            forecastsByDay[id] = byDay
            dateSets.append(days)
        }

        guard var commonDays = dateSets.first else { return nil }
        for set in dateSets.dropFirst() {
            commonDays.formIntersection(set)
        }

        let sortedDays = commonDays.sorted { lhs, rhs in
            calendar.date(from: lhs)! < calendar.date(from: rhs)!
        }
        guard sortedDays.count >= minimumWindowLength else { return nil }

        func badness(for day: DateComponents) -> Double {
            let values = forecasts.keys.compactMap { forecastsByDay[$0]?[day] }
            guard !values.isEmpty else { return .infinity }
            let total = values.reduce(0.0) { $0 + Double($1.rainProbability) + conditionPenalty($1.condition) }
            return total / Double(values.count)
        }

        func isAllClear(for day: DateComponents) -> Bool {
            forecasts.keys.allSatisfy { forecastsByDay[$0]?[day]?.condition == .clear }
        }

        var best: (range: Range<Int>, score: Double)?
        for length in minimumWindowLength...sortedDays.count {
            for start in 0...(sortedDays.count - length) {
                let range = start..<(start + length)
                let score = range
                    .map { badness(for: sortedDays[$0]) }
                    .reduce(0.0, +) / Double(length)

                if let current = best {
                    if score < current.score - 1e-9 {
                        best = (range, score)
                    } else if abs(score - current.score) <= 1e-9 {
                        if length > current.range.count {
                            best = (range, score)
                        } else if length == current.range.count && start < current.range.lowerBound {
                            best = (range, score)
                        }
                    }
                } else {
                    best = (range, score)
                }
            }
        }

        guard let best else { return nil }
        let days = best.range.map { calendar.date(from: sortedDays[$0])! }
        let allClear = best.range.allSatisfy { isAllClear(for: sortedDays[$0]) }
        return BestWindow(days: days, score: best.score, isAllClear: allClear)
    }
}
