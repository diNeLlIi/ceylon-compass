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

enum Band: String, Equatable {
    case ideal, good, fair

    static let idealThreshold = 85
    static let goodThreshold = 70

    static func of(_ score: Int) -> Band {
        if score >= idealThreshold { return .ideal }
        if score >= goodThreshold { return .good }
        return .fair
    }

    var displayName: String {
        switch self {
        case .ideal: return "Ideal"
        case .good: return "Good"
        case .fair: return "Fair"
        }
    }

    var systemImage: String {
        switch self {
        case .ideal: return "sun.max.fill"
        case .good: return "sun.min.fill"
        case .fair: return "cloud.fill"
        }
    }
}

struct DestinationWeatherScore: Equatable, Identifiable {
    let destinationId: UUID
    let score: Int
    let band: Band
    let avgHigh: Double
    let avgRainPct: Int
    let avgSunHours: Double
    let evaluatedDayCount: Int

    var id: UUID { destinationId }
}

enum BestWindowCalculator {
    static func conditionPenalty(_ condition: WeatherCondition) -> Double {
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

    // Scopes bestWindow to a specific set of days (the active CompareWindow).
    static func bestWindow(
        forecasts: [UUID: [DayForecast]],
        inDays days: [Date],
        minimumWindowLength: Int = 2,
        minimumDestinations: Int = 2
    ) -> BestWindow? {
        let calendar = Calendar.current
        let allowed = Set(days.map { calendar.dateComponents([.year, .month, .day], from: $0) })
        let scoped = forecasts.mapValues { entries in
            entries.filter { allowed.contains(calendar.dateComponents([.year, .month, .day], from: $0.date)) }
        }
        return bestWindow(forecasts: scoped, minimumWindowLength: minimumWindowLength, minimumDestinations: minimumDestinations)
    }

    // Per-destination weather score over an explicit day set: the metric powering the ranked list
    static func score(
        destinationId: UUID,
        forecasts: [DayForecast],
        over days: [Date]
    ) -> DestinationWeatherScore? {
        let calendar = Calendar.current
        let allowed = Set(days.map { calendar.dateComponents([.year, .month, .day], from: $0) })
        let scoped = forecasts.filter { allowed.contains(calendar.dateComponents([.year, .month, .day], from: $0.date)) }
        guard !scoped.isEmpty else { return nil }

        let count = Double(scoped.count)
        let badness = scoped.reduce(0.0) { $0 + Double($1.rainProbability) + conditionPenalty($1.condition) } / count
        let rawScore = (100 - badness).rounded()
        let clampedScore = Int(max(0, min(100, rawScore)))
        let avgHigh = scoped.reduce(0.0) { $0 + $1.high } / count
        let avgRainPct = Int((scoped.reduce(0.0) { $0 + Double($1.rainProbability) } / count).rounded())
        let avgSunHours = scoped.reduce(0.0) { $0 + $1.sunHours } / count

        return DestinationWeatherScore(
            destinationId: destinationId,
            score: clampedScore,
            band: .of(clampedScore),
            avgHigh: avgHigh,
            avgRainPct: avgRainPct,
            avgSunHours: avgSunHours,
            evaluatedDayCount: scoped.count
        )
    }
}
