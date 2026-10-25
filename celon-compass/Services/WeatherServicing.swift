//
//  WeatherServicing.swift
//  celon-compass
//

internal import Foundation

protocol WeatherServicing {
    @MainActor
    func forecasts(for destinations: [Destination]) async throws -> [UUID: [DayForecast]]
}
