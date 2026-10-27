//
//  WeatherCondition.swift
//  celon-compass
//

enum WeatherCondition: String, Codable, CaseIterable {
    case clear, cloudy, rain, storm

    // WMO weather codes per Open-Meteo
    static func from(wmoCode: Int) -> WeatherCondition {
        switch wmoCode {
        case 80...: return .storm
        case 51...77: return .rain
        case 1...3, 45, 48: return .cloudy
        case 0: return .clear
        default: return .cloudy
        }
    }

    var symbolName: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        case .storm: return "cloud.bolt.rain.fill"
        }
    }

    // Night variants so an evening hour doesn't render a sun glyph.
    func symbolName(isNight: Bool) -> String {
        guard isNight else { return symbolName }
        switch self {
        case .clear: return "moon.stars.fill"
        case .cloudy: return "cloud.moon.fill"
        case .rain: return "cloud.moon.rain.fill"
        case .storm: return "cloud.bolt.rain.fill"
        }
    }

    var label: String {
        switch self {
        case .clear: return "Clear"
        case .cloudy: return "Mostly Cloudy"
        case .rain: return "Rain"
        case .storm: return "Storms"
        }
    }
}
