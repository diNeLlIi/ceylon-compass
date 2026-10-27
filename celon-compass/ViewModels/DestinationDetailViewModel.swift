//
//  DestinationDetailViewModel.swift
//  celon-compass
//

import Combine
import Foundation

@MainActor
final class DestinationDetailViewModel: ObservableObject {
    let destination: Destination
    @Published private(set) var forecasts: [DayForecast]
    let favouritesStore: FavouritesStore

    init(destination: Destination, forecasts: [DayForecast], favouritesStore: FavouritesStore = .shared) {
        self.destination = destination
        self.forecasts = forecasts
        self.favouritesStore = favouritesStore
    }

    private var destinationId: UUID { destination.id ?? UUID() }

    var isFavourite: Bool { favouritesStore.isFavourite(destinationId) }

    func toggleFavourite() {
        favouritesStore.toggle(destinationId)
    }

    var coordinate: Coordinate {
        Coordinate(latitude: destination.latitude, longitude: destination.longitude)
    }


    var bestWindow: BestWindow? {
        guard !forecasts.isEmpty else { return nil }
        return BestWindowCalculator.bestWindow(
            forecasts: [destinationId: forecasts],
            minimumDestinations: 1
        )
    }

    var bestWindowDays: Set<DateComponents> {
        let calendar = Calendar.current
        return Set((bestWindow?.days ?? []).map {
            calendar.dateComponents([.year, .month, .day], from: $0)
        })
    }

    func isInBestWindow(_ forecast: DayForecast) -> Bool {
        let calendar = Calendar.current
        return bestWindowDays.contains(calendar.dateComponents([.year, .month, .day], from: forecast.date))
    }

    
    var forecastSpan: String {
        let calendar = Calendar.current
        guard let first = forecasts.first?.date, let last = forecasts.last?.date else { return "" }
        if calendar.isDate(first, inSameDayAs: last) {
            return first.formatted(.dateTime.day().month(.abbreviated))
        }
        let sameMonth = calendar.component(.month, from: first) == calendar.component(.month, from: last)
        let start = sameMonth
            ? first.formatted(.dateTime.day())
            : first.formatted(.dateTime.day().month(.abbreviated))
        return "\(start)–\(last.formatted(.dateTime.day().month(.abbreviated)))"
    }


//    var forecastWeeks: [ForecastWeek] {
//        guard !forecasts.isEmpty else { return [] }
//        let calendar = Calendar.current
//        let sorted = forecasts.sorted { $0.date < $1.date }
//
//        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: calendar.startOfDay(for: .now))?.start else {
//            return [makeWeek(id: 0, title: "Forecast", days: sorted)]
//        }
//
//        var buckets: [Int: [DayForecast]] = [:]
//        for forecast in sorted {
//            let weekStart = calendar.dateInterval(of: .weekOfYear, for: forecast.date)?.start ?? thisWeekStart
//            let offset = calendar.dateComponents([.weekOfYear], from: thisWeekStart, to: weekStart).weekOfYear ?? 0
//            buckets[offset, default: []].append(forecast)
//        }
//
//        return buckets.keys.sorted().compactMap { offset in
//            guard let days = buckets[offset], let first = days.first else { return nil }
//            return makeWeek(id: offset, title: Self.weekTitle(offset: offset, start: first.date), days: days)
//        }
//    }
//
//    private func makeWeek(id: Int, title: String, days: [DayForecast]) -> ForecastWeek {
//        let lows = days.map(\.low)
//        let highs = days.map(\.high)
//        let avgRain = days.isEmpty
//            ? 0
//            : Int((days.reduce(0.0) { $0 + Double($1.rainProbability) } / Double(days.count)).rounded())
//
//        return ForecastWeek(
//            id: id,
//            title: title,
//            dateRange: Self.weekRangeLabel(days: days),
//            days: days,
//            dominantCondition: Self.dominantCondition(in: days),
//            lowTemp: lows.min() ?? 0,
//            highTemp: highs.max() ?? 0,
//            avgRain: avgRain,
//            bestDayCount: days.filter(isInBestWindow).count
//        )
//    }
//
    
    
//    private static func dominantCondition(in days: [DayForecast]) -> WeatherCondition {
//        var counts: [WeatherCondition: Int] = [:]
//        for day in days { counts[day.condition, default: 0] += 1 }
//        return counts
//            .sorted {
//                $0.value == $1.value
//                    ? severity($0.key) > severity($1.key)
//                    : $0.value > $1.value
//            }
//            .first?.key ?? .cloudy
//    }
//
//    private static func severity(_ condition: WeatherCondition) -> Int {
//        switch condition {
//        case .clear: return 0
//        case .cloudy: return 1
//        case .rain: return 2
//        case .storm: return 3
//        }
//    }
//
//    private static func weekTitle(offset: Int, start: Date) -> String {
//        switch offset {
//        case 0: return "This week"
//        case 1: return "Next week"
//        default: return "Week of \(start.formatted(.dateTime.day().month(.abbreviated)))"
//        }
//    }
//
    
    

//    private static func weekRangeLabel(days: [DayForecast]) -> String {
//        let calendar = Calendar.current
//        guard let first = days.first?.date else { return "" }
//        let weekEnd: Date = {
//            guard let interval = calendar.dateInterval(of: .weekOfYear, for: first) else {
//                return days.last?.date ?? first
//            }
//            return calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
//        }()
//
//        let sameMonth = calendar.component(.month, from: first) == calendar.component(.month, from: weekEnd)
//        let start = sameMonth
//            ? first.formatted(.dateTime.day())
//            : first.formatted(.dateTime.day().month(.abbreviated))
//        return "\(start)–\(weekEnd.formatted(.dateTime.day().month(.abbreviated)))"
//    }
}

//struct ForecastWeek: Identifiable {
//    let id: Int
//    let title: String
//    let dateRange: String
//    let days: [DayForecast]
//    let dominantCondition: WeatherCondition
//    let lowTemp: Double
//    let highTemp: Double
//    let avgRain: Int
//    let bestDayCount: Int
//
//    var containsBestWindow: Bool { bestDayCount > 0 }
//
//    var bestDayBadge: String { bestDayCount == 1 ? "BEST DAY" : "BEST DAYS" }
//
//    var tempRange: String {
//        "\(Int(lowTemp.rounded()))–\(Int(highTemp.rounded()))°"
//    }
//
//    var accessibilitySummary: String {
//        "\(dominantCondition.label), \(tempRange), \(avgRain) percent chance of rain"
//    }
//}
