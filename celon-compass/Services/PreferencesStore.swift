//
//  PreferencesStore.swift
//  celon-compass
//
//  User preferences shown in Settings - Preferences
//

import Foundation
import Observation

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius
    case fahrenheit

    var id: String { rawValue }
    var symbol: String { self == .celsius ? "°C" : "°F" }
    var name: String { self == .celsius ? "Celsius" : "Fahrenheit" }
}

enum TravelInterest: String, CaseIterable, Identifiable {
    case beach = "Beach"
    case mountain = "Mountain"
    case heritage = "Heritage"
    case wildlife = "Wildlife"
    case waterfalls = "Waterfalls"
    case temples = "Temples"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .beach: "water.waves"
        case .mountain: "mountain.2"
        case .heritage: "building.columns"
        case .wildlife: "pawprint"
        case .waterfalls: "drop.triangle"
        case .temples: "building"
        }
    }
}

@MainActor
@Observable
final class PreferencesStore {
    static let shared = PreferencesStore()

    enum Key {
        static let temperatureUnit = "temperatureUnit"
        static let weatherAlerts = "weatherAlertsEnabled"
        static let tripReminders = "tripRemindersEnabled"
        static let hasOnboarded = "hasOnboarded"
        static let homeCity = "homeCity"
        static let interests = "interests"
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
    var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: Key.hasOnboarded) }
    }
    var homeCity: String {
        didSet { defaults.set(homeCity, forKey: Key.homeCity) }
    }
    var interests: Set<TravelInterest> {
        didSet {
            defaults.set(interests.map(\.rawValue), forKey: Key.interests)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        temperatureUnit = defaults.string(forKey: Key.temperatureUnit)
            .flatMap(TemperatureUnit.init(rawValue:)) ?? .celsius
        weatherAlertsEnabled = defaults.bool(forKey: Key.weatherAlerts)
        tripRemindersEnabled = defaults.bool(forKey: Key.tripReminders)
        hasOnboarded = defaults.bool(forKey: Key.hasOnboarded)
        homeCity = defaults.string(forKey: Key.homeCity) ?? ""
        let saved = defaults.stringArray(forKey: Key.interests) ?? []
        interests = Set(saved.compactMap(TravelInterest.init(rawValue:)))
    }
}
