//
//  CompareDestinationsView.swift
//  celon-compass
//

import SwiftUI

struct CompareDestinationsView: View {
    let destinations: [Destination]
    let forecasts: [UUID: [DayForecast]]
    @Bindable var selection: CompareSelection
    @Environment(\.dismiss) private var dismiss

    private var selectedDestinations: [Destination] {
        selection.orderedIds.compactMap { id in
            destinations.first { $0.id == id }
        }
    }

    private var selectedForecasts: [UUID: [DayForecast]] {
        forecasts.filter { selection.isSelected($0.key) }
    }

    private var bestWindow: BestWindow? {
        BestWindowCalculator.bestWindow(forecasts: selectedForecasts)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CompareChipRowView(destinations: selectedDestinations) { id in
                    selection.remove(id)
                }

                bestWindowBanner
                    .padding(.horizontal)

                CompareWeatherTableView(
                    destinations: selectedDestinations,
                    forecasts: forecasts,
                    bestWindowDays: Set(bestWindow?.days ?? [])
                )

                TemperatureTrendChartView(destinations: selectedDestinations, forecasts: forecasts)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(AppBrand.canvas)
        .navigationTitle("Compare destinations")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selection.count) {
            
            if selection.count < CompareSelection.minCount {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var bestWindowBanner: some View {
        if let bestWindow, let first = bestWindow.days.first, let last = bestWindow.days.last {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                Text(bannerText(first: first, last: last, isAllClear: bestWindow.isAllClear))
                    .font(.subheadline.weight(.medium))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppBrand.tealTop.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        } else {
            Text("Not enough overlapping forecast data to find a shared window yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func bannerText(first: Date, last: Date, isAllClear: Bool) -> String {
        let formatter = Date.FormatStyle().month(.abbreviated).day()
        let range = first == last
            ? first.formatted(formatter)
            : "\(first.formatted(formatter))–\(last.formatted(.dateTime.day()))"
        let condition = isAllClear ? "Clear" : "Low rain risk"
        return "Best window · \(range) · \(condition) across all \(selectedDestinations.count) destinations"
    }
}
