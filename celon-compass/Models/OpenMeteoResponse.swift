//
//  OpenMeteoResponse.swift
//  celon-compass
//
//

import Foundation

struct OpenMeteoResponse: Codable {
    struct Daily: Codable {
        let time: [String]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let precipitation_probability_max: [Int]
        let uv_index_max: [Double]
        let weathercode: [Int]
    }

    let daily: Daily

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

        return try (0..<count).map { index in
            guard let date = Self.dateFormatter.date(from: daily.time[index]) else {
                throw WeatherError.decoding(DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "Unparseable date: \(daily.time[index])")
                ))
            }
            return DayForecast(
                date: date,
                high: daily.temperature_2m_max[index],
                low: daily.temperature_2m_min[index],
                rainProbability: daily.precipitation_probability_max[index],
                uvIndex: daily.uv_index_max[index],
                condition: .from(wmoCode: daily.weathercode[index])
            )
        }
    }

    // Open-Meteo's `time` field is bare "yyyy-MM-dd" — .iso8601 fails on this format.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
