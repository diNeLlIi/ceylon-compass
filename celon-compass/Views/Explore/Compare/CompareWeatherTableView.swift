//
//  CompareWeatherTableView.swift
//  celon-compass
//

import SwiftUI
internal import Foundation

struct CompareWeatherTableView: View {
    let destinations: [Destination]
    let forecasts: [UUID: [DayForecast]]
    let bestWindowDays: Set<Date>

    private var days: [Date] {
        let calendar = Calendar.current
        var seen: Set<DateComponents> = []
        var ordered: [Date] = []
        for destination in destinations {
            guard let id = destination.id else { continue }
            for forecast in forecasts[id] ?? [] {
                let components = calendar.dateComponents([.year, .month, .day], from: forecast.date)
                if seen.insert(components).inserted {
                    ordered.append(forecast.date)
                }
            }
        }
        return ordered.sorted().prefix(7).map { $0 }
    }

    private func forecast(for destination: Destination, on day: Date) -> DayForecast? {
        guard let id = destination.id else { return nil }
        let calendar = Calendar.current
        return forecasts[id]?.first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    private func isBestWindow(_ day: Date) -> Bool {
        let calendar = Calendar.current
        return bestWindowDays.contains { calendar.isDate($0, inSameDayAs: day) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(horizontalSpacing: 4, verticalSpacing: 8) {
                GridRow {
                    Text("")
                        .frame(width: 80, alignment: .leading)
                    ForEach(days, id: \.self) { day in
                        dayHeader(day)
                    }
                }
                ForEach(destinations, id: \.id) { destination in
                    GridRow {
                        Text(destination.name ?? "Unknown")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .frame(width: 80, alignment: .leading)
                        ForEach(days, id: \.self) { day in
                            cell(destination: destination, day: day)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func dayHeader(_ day: Date) -> some View {
        VStack(spacing: 2) {
            Text(day, format: .dateTime.weekday(.abbreviated))
                .font(.caption2.weight(.semibold))
            Text(day, format: .dateTime.day())
                .font(.caption2)
        }
        .frame(width: 52)
        .padding(.vertical, 4)
        .background(isBestWindow(day) ? AppBrand.tealTop.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func cell(destination: Destination, day: Date) -> some View {
        VStack(spacing: 2) {
            if let forecast = forecast(for: destination, on: day) {
                Image(systemName: forecast.condition.symbolName)
                    .font(.caption)
                Text("\(Int(forecast.high.rounded()))°")
                    .font(.caption2.weight(.semibold))
                Text("\(forecast.rainProbability)%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("–")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 52)
        .padding(.vertical, 4)
        .background(isBestWindow(day) ? AppBrand.tealTop.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
