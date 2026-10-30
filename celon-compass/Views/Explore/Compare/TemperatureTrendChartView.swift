//
//  TemperatureTrendChartView.swift
//  celon-compass
//
//  Needs the Charts system framework linked on the app target
//

import SwiftUI
import Charts

struct TemperatureTrendChartView: View {
    let destinations: [Destination]
    let forecasts: [UUID: [DayForecast]]

    private static let seriesColors: [Color] = [AppBrand.accent, AppBrand.amber, AppBrand.accentStrong]

    private struct Point: Identifiable {
        let id = UUID()
        let destinationName: String
        let date: Date
        let high: Double
    }

    private var points: [Point] {
        destinations.flatMap { destination -> [Point] in
            guard let id = destination.id else { return [] }
            let name = destination.name ?? "Unknown"
            return (forecasts[id] ?? []).map { Point(destinationName: name, date: $0.date, high: $0.high) }
        }
    }

    private var destinationNames: [String] {
        destinations.map { $0.name ?? "Unknown" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Temperature trend")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Daily high, °C")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(points) { point in
                LineMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("High", point.high)
                )
                .foregroundStyle(by: .value("Destination", point.destinationName))
                .symbol(by: .value("Destination", point.destinationName))
            }
            .chartForegroundStyleScale(domain: destinationNames, range: Self.seriesColors)
            .frame(height: 180)
        }
    }
}
