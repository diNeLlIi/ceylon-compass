//
//  CheckWeatherIntent.swift
//  celon-compass
//

import AppIntents
import Foundation

struct CheckWeatherIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Weather"
    static var description = IntentDescription("Checks the latest cached forecast for a destination.")

    @Parameter(title: "Destination")
    var destination: DestinationEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Check weather in \(\.$destination)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let uuid = UUID(uuidString: destination.id),
              let forecast = WeatherCache.freshForecasts(for: uuid, ttl: 3 * 3600)?.first
        else {
            return .result(dialog: "I don't have fresh weather for \(destination.name) yet. Open \(AppBrand.name) to refresh it.")
        }
        let high = Int(forecast.high.rounded())
        return .result(dialog: "\(destination.name) is \(high)° and \(forecast.condition.label.lowercased()) today.")
    }
}
