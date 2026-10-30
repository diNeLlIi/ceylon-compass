//
//  CompareWeatherTableView.swift
//  celon-compass
//

import SwiftUI
import Foundation

struct CompareWeatherTableView: View {
    let destinations: [Destination]
    let forecasts: [UUID: [DayForecast]]
    let visibleDays: [Date]
    let bestWindowDays: Set<Date>

    private static let destColumnWidth: CGFloat = 92
    private static let cellWidth: CGFloat = 60
    // Was 76. UV is its own line rather than a fourth value crammed into the old height,
    // which already held an icon, a temperature and a rain figure.
    private static let rowHeight: CGFloat = 98

    private var days: [Date] {
        let calendar = Calendar.current
        var seen: Set<DateComponents> = []
        var ordered: [Date] = []
        for day in visibleDays {
            let components = calendar.dateComponents([.year, .month, .day], from: day)
            if seen.insert(components).inserted {
                ordered.append(day)
            }
        }
        return ordered
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Forecast")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppBrand.heading)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    ForEach(destinations, id: \.id) { destination in
                        row(for: destination)
                    }
                }
                .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
                )
                .padding(.horizontal)
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Self.destColumnWidth, height: 48)
            ForEach(days, id: \.self) { day in
                VStack(spacing: 2) {
                    Text(day, format: .dateTime.weekday(.abbreviated))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(day, format: .dateTime.day())
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppBrand.heading)
                }
                .frame(width: Self.cellWidth, height: 48)
                .background(isBestWindow(day) ? AppBrand.accentTint : Color.clear)
            }
        }
    }

    private func row(for destination: Destination) -> some View {
        HStack(spacing: 0) {
            destinationCell(destination)
            ForEach(days, id: \.self) { day in
                cell(destination: destination, day: day)
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(.separator).opacity(0.5))
                .frame(height: 1)
        }
    }

    private func destinationCell(_ destination: Destination) -> some View {
        HStack(spacing: 8) {
            avatar(for: destination)
            Text(destination.name ?? "Unknown")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppBrand.heading)
                // Two lines rather than one: the taller UV row leaves the vertical space,
                // and "Horton Plains" truncated to "Horton…" on a single line.
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        // Padding goes INSIDE the fixed width. Applied after .frame it added to the column,
        // making it 102pt against the header's 92pt spacer and shifting every data column
        // 10pt right of the date it belongs to.
        .padding(.leading, 10)
        .frame(width: Self.destColumnWidth, height: Self.rowHeight, alignment: .leading)
    }

    @ViewBuilder
    private func avatar(for destination: Destination) -> some View {
        if let url = destination.imageURL.flatMap(URL.init(string:)) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Color(.secondarySystemBackground)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(AppBrand.accentTint)
                .frame(width: 32, height: 32)
        }
    }

    @ViewBuilder
    private func cell(destination: Destination, day: Date) -> some View {
        VStack(spacing: 3) {
            if let forecast = forecast(for: destination, on: day) {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: forecast.condition.symbolName)
                            .font(.subheadline)
                            .foregroundStyle(forecast.condition.tint)
                    }
                Text("\(Int(forecast.high.rounded()))°")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(AppBrand.heading)
                Text("\(forecast.rainProbability)%")
                    .font(.caption2)
                    .foregroundStyle(AppBrand.link)
                Text("UV \(Int(forecast.uvIndex.rounded()))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(UVBand.of(forecast.uvIndex).tint)
            } else {
                Text("–")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: Self.cellWidth, height: Self.rowHeight)
        .background(isBestWindow(day) ? AppBrand.accentTint : Color.clear)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cellAccessibilityLabel(destination: destination, day: day))
    }

    private func cellAccessibilityLabel(destination: Destination, day: Date) -> String {
        let dayText = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard let forecast = forecast(for: destination, on: day) else {
            return "\(destination.name ?? "Unknown"), \(dayText), no forecast"
        }
        let band = UVBand.of(forecast.uvIndex)
        return "\(destination.name ?? "Unknown"), \(dayText), \(forecast.condition.label), "
            + "\(Int(forecast.high.rounded())) degrees, \(forecast.rainProbability) percent rain, "
            + "UV \(Int(forecast.uvIndex.rounded())), \(band.label.lowercased())"
    }
}

// WHO bands. Never colour alone: the number and the band name both ship, because a
// red "11" means nothing to a user who can't distinguish it from the amber one.
enum UVBand {
    case low, moderate, high, veryHigh, extreme

    static func of(_ index: Double) -> UVBand {
        switch index {
        case ..<3: .low
        case ..<6: .moderate
        case ..<8: .high
        case ..<11: .veryHigh
        default: .extreme
        }
    }

    var label: String {
        switch self {
        case .low: "Low"
        case .moderate: "Moderate"
        case .high: "High"
        case .veryHigh: "Very High"
        case .extreme: "Extreme"
        }
    }

    var tint: Color {
        switch self {
        case .low: AppBrand.success
        case .moderate: AppBrand.accent
        case .high: AppBrand.amber
        case .veryHigh, .extreme: AppBrand.destructive
        }
    }
}

private extension WeatherCondition {
    var tint: Color {
        switch self {
        case .clear: return AppBrand.amber
        case .cloudy: return .secondary
        case .rain: return AppBrand.link
        case .storm: return AppBrand.destructive
        }
    }
}
