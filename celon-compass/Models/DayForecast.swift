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
}
