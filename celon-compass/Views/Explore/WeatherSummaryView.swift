//
//  WeatherSummaryView.swift
//  celon-compass

import SwiftUI

struct WeatherSummaryView: View {
    let sunnyCount: Int
    let rainyCount: Int
    let totalCount: Int

    private var cloudyCount: Int {
        totalCount - sunnyCount - rainyCount
    }

    var body: some View {
        HStack(spacing: 16) {
            weatherPill(icon: "sun.max.fill", count: sunnyCount, label: "sunny", color: AppBrand.amber)
            weatherPill(icon: "cloud.fill", count: cloudyCount, label: "cloudy", color: .gray)
            weatherPill(icon: "cloud.rain.fill", count: rainyCount, label: "rainy", color: AppBrand.link)
        }
        .padding(.horizontal)
    }

    private func weatherPill(icon: String, count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text("\(count) \(label)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemBackground), in: Capsule())
    }
}
