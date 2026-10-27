//
//  DayForecast.swift
//  celon-compass
//

import Foundation

struct DayForecast: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let high: Double
    let low: Double
    let rainProbability: Int
    let uvIndex: Double
    let condition: WeatherCondition
    let sunHours: Double
    let sunrise: Date?
    let sunset: Date?
    // Populated only for the first couple of days — see OpenMeteoResponse.hourlyRetentionDays.
    let hours: [HourForecast]

    init(
        date: Date,
        high: Double,
        low: Double,
        rainProbability: Int,
        uvIndex: Double,
        condition: WeatherCondition,
        sunHours: Double = 0,
        sunrise: Date? = nil,
        sunset: Date? = nil,
        hours: [HourForecast] = []
    ) {
        self.date = date
        self.high = high
        self.low = low
        self.rainProbability = rainProbability
        self.uvIndex = uvIndex
        self.condition = condition
        self.sunHours = sunHours
        self.sunrise = sunrise
        self.sunset = sunset
        self.hours = hours
    }

    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        high = try container.decode(Double.self, forKey: .high)
        low = try container.decode(Double.self, forKey: .low)
        rainProbability = try container.decode(Int.self, forKey: .rainProbability)
        uvIndex = try container.decode(Double.self, forKey: .uvIndex)
        condition = try container.decode(WeatherCondition.self, forKey: .condition)
        sunHours = try container.decodeIfPresent(Double.self, forKey: .sunHours) ?? 0
        sunrise = try container.decodeIfPresent(Date.self, forKey: .sunrise)
        sunset = try container.decodeIfPresent(Date.self, forKey: .sunset)
        hours = try container.decodeIfPresent([HourForecast].self, forKey: .hours) ?? []
    }
}
