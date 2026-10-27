//
//  OpenMeteoResponse.swift
//  celon-compass
//
//

import Foundation

struct OpenMeteoResponse: Codable {

    static let hourlyRetentionDays = 2

    struct Daily: Codable {
        let time: [String]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let precipitation_probability_max: [Int]
        let uv_index_max: [Double]
        let weathercode: [Int]
        let sunshine_duration: [Double]?
        let sunrise: [String]?
        let sunset: [String]?
    }

    struct Hourly: Codable {
        let time: [String]
        let temperature_2m: [Double]
        let precipitation_probability: [Int?]
        let weathercode: [Int]
    }

    let daily: Daily
    let hourly: Hourly?

    func toDayForecasts() throws -> [DayForecast] {
        let count = daily.time.count
        guard daily.temperature_2m_max.count == count,
              daily.temperature_2m_min.count == count,
              daily.precipitation_probability_max.count == count,
              daily.uv_index_max.count == count,
              daily.weathercode.count == count else {
            throw WeatherError.decoding(DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Open-Meteo daily arrays have mismatched lengths")
            ))
        }

        let hourlyByDay = bucketHourlyByDay()

        return try (0..<count).map { index in
            guard let date = Self.dayFormatter.date(from: daily.time[index]) else {
                throw WeatherError.decoding(DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "Unparseable date: \(daily.time[index])")
                ))
            }
            let sunSeconds: Double = {
                guard let sun = daily.sunshine_duration, index < sun.count else { return 0 }
                return sun[index]
            }()
            let dayKey = WallClock.calendar.dateComponents([.year, .month, .day], from: date)
            return DayForecast(
                date: date,
                high: daily.temperature_2m_max[index],
                low: daily.temperature_2m_min[index],
                rainProbability: daily.precipitation_probability_max[index],
                uvIndex: daily.uv_index_max[index],
                condition: .from(wmoCode: daily.weathercode[index]),
                sunHours: sunSeconds / 3600,
                sunrise: timestamp(from: daily.sunrise, at: index),
                sunset: timestamp(from: daily.sunset, at: index),
                hours: index < Self.hourlyRetentionDays ? (hourlyByDay[dayKey] ?? []) : []
            )
        }
    }

    private func timestamp(from array: [String]?, at index: Int) -> Date? {
        guard let array, index < array.count else { return nil }
        return Self.timeFormatter.date(from: array[index])
    }

    private func bucketHourlyByDay() -> [DateComponents: [HourForecast]] {
        guard let hourly else { return [:] }
        let count = hourly.time.count
        guard hourly.temperature_2m.count == count, hourly.weathercode.count == count else { return [:] }

        var buckets: [DateComponents: [HourForecast]] = [:]
        for index in 0..<count {
            guard let time = Self.timeFormatter.date(from: hourly.time[index]) else { continue }
            let rain = index < hourly.precipitation_probability.count
                ? (hourly.precipitation_probability[index] ?? 0)
                : 0
            let slot = HourForecast(
                time: time,
                temperature: hourly.temperature_2m[index],
                rainProbability: rain,
                condition: .from(wmoCode: hourly.weathercode[index])
            )
            let key = WallClock.calendar.dateComponents([.year, .month, .day], from: time)
            buckets[key, default: []].append(slot)
        }
        return buckets.mapValues { $0.sorted { $0.time < $1.time } }
    }

    // Open-Meteo's daily time is bare "yyyy-MM-dd"
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
