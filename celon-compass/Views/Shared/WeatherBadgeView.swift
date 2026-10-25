//
//  WeatherBadgeView.swift
//  celon-compass

import SwiftUI

struct WeatherBadgeView: View {
    let forecast: DayForecast?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
            if let forecast {
                Text("\(Int(forecast.high.rounded()))°")

                if forecast.rainProbability > 0 {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 8))
                    Text("\(forecast.rainProbability)%")
                }
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial.opacity(0.8), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
        .accessibilityLabel(accessibilityLabel)
    }

    private var symbolName: String {
        forecast?.condition.symbolName ?? "cloud.slash"
    }

    private var accessibilityLabel: String {
        guard let forecast else { return "Weather unavailable" }
        var label = "\(forecast.condition.rawValue.capitalized), \(Int(forecast.high.rounded())) degrees"
        if forecast.rainProbability > 0 {
            label += ", \(forecast.rainProbability) percent chance of rain"
        }
        return label
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
