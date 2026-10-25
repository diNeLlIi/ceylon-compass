//
//  PreferencesStore.swift
//  celon-compass
//
//  User preferences shown in Settings - Preferences
//

internal import Foundation
import Observation

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius
    case fahrenheit

    var id: String { rawValue }
    var symbol: String { self == .celsius ? "°C" : "°F" }
    var name: String { self == .celsius ? "Celsius" : "Fahrenheit" }
}

@MainActor
@Observable
final class PreferencesStore {
    static let shared = PreferencesStore()

    enum Key {
        static let temperatureUnit = "temperatureUnit"
        static let weatherAlerts = "weatherAlertsEnabled"
        static let tripReminders = "tripRemindersEnabled"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: Key.temperatureUnit) }
    }
    var weatherAlertsEnabled: Bool {
        didSet { defaults.set(weatherAlertsEnabled, forKey: Key.weatherAlerts) }
    }
    var tripRemindersEnabled: Bool {
        didSet { defaults.set(tripRemindersEnabled, forKey: Key.tripReminders) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        temperatureUnit = defaults.string(forKey: Key.temperatureUnit)
            .flatMap(TemperatureUnit.init(rawValue:)) ?? .celsius
        weatherAlertsEnabled = defaults.bool(forKey: Key.weatherAlerts)
        tripRemindersEnabled = defaults.bool(forKey: Key.tripReminders)
    }
}
