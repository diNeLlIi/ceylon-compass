//
//  WeatherBadgeView.swift
//  celon-compass
//

//

import SwiftUI

struct WeatherBadgeView: View {
    let forecast: DayForecast?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
            if let forecast {
                Text("\(Int(forecast.high.rounded()))°")
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.45), in: Capsule())
        .accessibilityLabel(accessibilityLabel)
    }

    private var symbolName: String {
        guard let condition = forecast?.condition else { return "cloud.slash" }
        switch condition {
        case .clear: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        case .storm: return "cloud.bolt.rain.fill"
        }
    }

    private var accessibilityLabel: String {
        guard let forecast else { return "Weather unavailable" }
        return "\(forecast.condition.rawValue.capitalized), \(Int(forecast.high.rounded())) degrees"
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            ForEach(WeatherCondition.allCases, id: \.self) { condition in
                WeatherBadgeView(forecast: DayForecast(
                    date: .now, high: 30, low: 24, rainProbability: 10, uvIndex: 7, condition: condition
                ))
            }
        }
        WeatherBadgeView(forecast: nil)
    }
    .padding()
    .background(Color.gray)
}
