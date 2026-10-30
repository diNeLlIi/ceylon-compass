//
//  WeatherBadgeView.swift
//  celon-compass

import SwiftUI

struct WeatherBadgeView: View {

    enum Style {
        case onImage
        case onSurface
    }

    let forecast: DayForecast?
    var style: Style = .onImage

    var detailed: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
            if let forecast {
                Text("\(Int(forecast.high.rounded()))°")

                if detailed {
                    Text(forecast.condition.rawValue.capitalized)
                }

                if forecast.rainProbability > 0 {
                    if detailed {
                        Text("· \(forecast.rainProbability)% rain")
                    } else {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 8))
                        Text("\(forecast.rainProbability)%")
                    }
                }
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(background)
        .overlay(capsuleStroke)
        .accessibilityLabel(accessibilityLabel)
    }

    private var foregroundColor: Color {
        switch style {
        case .onImage: .white
        case .onSurface: AppBrand.accentStrong
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .onImage:
            Capsule().fill(.ultraThinMaterial.opacity(0.8))
        case .onSurface:
            Capsule().fill(AppBrand.accentTint)
        }
    }

    @ViewBuilder
    private var capsuleStroke: some View {
        if style == .onImage {
            Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5)
        }
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

    VStack(spacing: 16) {
        HStack(spacing: 16) {
            ForEach(WeatherCondition.allCases, id: \.self) { condition in
                WeatherBadgeView(
                    forecast: DayForecast(date: .now, high: 30, low: 24, rainProbability: 10, uvIndex: 7, condition: condition),
                    style: .onSurface
                )
            }
        }
        WeatherBadgeView(forecast: nil, style: .onSurface)
    }
    .padding()
    .background(AppBrand.card)

    VStack(alignment: .leading, spacing: 10) {
        ForEach(WeatherCondition.allCases, id: \.self) { condition in
            WeatherBadgeView(
                forecast: DayForecast(date: .now, high: 30, low: 24, rainProbability: 15, uvIndex: 7, condition: condition),
                style: .onSurface,
                detailed: true
            )
        }
    }
    .padding()
    .background(AppBrand.card)
}
