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
}
