//
//  PreferencesStore.swift
//  celon-compass
//
//  User preferences shown in Settings: Preferences

//  Synced keys (homeCity, interests, temperatureUnit, rainTolerance) delegate to
//  UserProfileStore so they live in Core Data and sync to Firestore.

//  Local-only keys (hasOnboarded, weatherAlerts, tripReminders, faceIDLock) stay
//  in UserDefaults.
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

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var name: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
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
        static let faceIDLock = "faceIDLockEnabled"
        static let appearanceMode = "appearanceMode"
    }

    @ObservationIgnored private let defaults: UserDefaults

    
    //Synced keys (delegated to UserProfileStore)

    var homeCity: String {
        get { UserProfileStore.shared.homeCity }
        set { UserProfileStore.shared.setHomeCity(newValue) }
    }

    var interests: Set<TravelInterest> {
        get { UserProfileStore.shared.interests }
        set { UserProfileStore.shared.setInterests(newValue) }
    }

    var temperatureUnit: TemperatureUnit {
        get { UserProfileStore.shared.temperatureUnit }
        set { UserProfileStore.shared.setTemperatureUnit(newValue) }
    }

    var rainTolerance: RainTolerance {
        get { UserProfileStore.shared.rainTolerance }
        set { UserProfileStore.shared.setRainTolerance(newValue) }
    }

    
    //Local-only keys (UserDefaults)

    var weatherAlertsEnabled: Bool {
        didSet { defaults.set(weatherAlertsEnabled, forKey: Key.weatherAlerts) }
    }
    var tripRemindersEnabled: Bool {
        didSet { defaults.set(tripRemindersEnabled, forKey: Key.tripReminders) }
    }
    var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: Key.hasOnboarded) }
    }
    var faceIDLockEnabled: Bool {
        didSet { defaults.set(faceIDLockEnabled, forKey: Key.faceIDLock) }
    }
    var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Key.appearanceMode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        weatherAlertsEnabled = defaults.bool(forKey: Key.weatherAlerts)
        tripRemindersEnabled = defaults.bool(forKey: Key.tripReminders)
        hasOnboarded = defaults.bool(forKey: Key.hasOnboarded)
        faceIDLockEnabled = defaults.bool(forKey: Key.faceIDLock)
        appearanceMode = defaults.string(forKey: Key.appearanceMode).flatMap(AppearanceMode.init) ?? .system
    }
}
