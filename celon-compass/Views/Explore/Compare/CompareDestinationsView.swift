//
//  CompareDestinationsView.swift
//  celon-compass
//

import SwiftUI
import CoreData

struct CompareDestinationsView: View {
    let destinations: [Destination]
    let forecasts: [UUID: [DayForecast]]
    @Bindable var selection: CompareSelection
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    @State private var window: CompareWindow = .next5
    @State private var showingPlanSheet = false
    @State private var shareImage: UIImage?

    private var selectedDestinations: [Destination] {
        selection.orderedIds.compactMap { id in
            destinations.first { $0.id == id }
        }
    }

    private var activeDays: [Date] {
        window.days()
    }

    private var scopedForecasts: [UUID: [DayForecast]] {
        let allowed = Set(activeDays.map { Calendar.current.dateComponents([.year, .month, .day], from: $0) })
        let calendar = Calendar.current
        return forecasts
            .filter { selection.isSelected($0.key) }
            .mapValues { entries in
                entries.filter { allowed.contains(calendar.dateComponents([.year, .month, .day], from: $0.date)) }
            }
    }

    private var bestWindow: BestWindow? {
        // Allow a 1-day recommendation when the user picks a single-day custom window;
        // the default 2-day minimum would otherwise always return nil for that case.
        let minLength = max(1, min(2, activeDays.count))
        return BestWindowCalculator.bestWindow(forecasts: scopedForecasts, minimumWindowLength: minLength)
    }

    private var scoredDestinations: [(Destination, DestinationWeatherScore)] {
        let scored: [(Destination, DestinationWeatherScore)] = selectedDestinations.compactMap { destination in
            guard let id = destination.id,
                  let forecast = forecasts[id],
                  let score = BestWindowCalculator.score(destinationId: id, forecasts: forecast, over: activeDays)
            else { return nil }
            return (destination, score)
        }
        return scored.sorted { $0.1.score > $1.1.score }
    }

    private var maxRainInBestWindow: Int? {
        guard let bestWindow else { return nil }
        var maxValue = 0
        let calendar = Calendar.current
        for day in bestWindow.days {
            for (_, entries) in scopedForecasts {
                if let match = entries.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
                    maxValue = max(maxValue, match.rainProbability)
                }
            }
        }
        return maxValue
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CompareChipRowView(destinations: selectedDestinations) { id in
                    selection.remove(id)
                }

                TimeWindowPickerView(window: $window)

                RecommendedWindowCard(
                    bestWindow: bestWindow,
                    maxRainPct: maxRainInBestWindow,
                    destinationCount: selectedDestinations.count,
                    shareImage: shareImage,
                    onPlan: { showingPlanSheet = true }
                )

                rankedSection

                CompareWeatherTableView(
                    destinations: selectedDestinations,
                    forecasts: forecasts,
                    visibleDays: activeDays,
                    bestWindowDays: Set(bestWindow?.days ?? [])
                )

                DisclosureGroup {
                    TemperatureTrendChartView(destinations: selectedDestinations, forecasts: scopedForecasts)
                        .padding(.top, 8)
                } label: {
                    Text("Temperature trend")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppBrand.navy)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
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
            regenerateShareImage()
        }
        .onChange(of: window) { regenerateShareImage() }
        .onAppear { regenerateShareImage() }
        .sheet(isPresented: $showingPlanSheet) {
            PlanFromCompareSheet(
                destinations: selectedDestinations,
                dayRange: bestWindow?.days ?? activeDays
            ) { _ in
                dismiss()
            }
            .environment(\.managedObjectContext, context)
        }
    }

    @ViewBuilder
    private var rankedSection: some View {
        if !scoredDestinations.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Ranked for this window")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppBrand.navy)
                    Spacer()
                    Text("Weather score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                ForEach(Array(scoredDestinations.enumerated()), id: \.offset) { indexed in
                    RankedDestinationRow(
                        rank: indexed.offset + 1,
                        destination: indexed.element.0,
                        score: indexed.element.1
                    )
                }
            }
        }
    }

    @MainActor
    private func regenerateShareImage() {
        let ranked: [(destination: Destination, score: DestinationWeatherScore)] =
            scoredDestinations.map { (destination: $0.0, score: $0.1) }
        let card = CompareShareCardView(window: bestWindow, ranked: ranked)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0
        shareImage = renderer.uiImage
    }
}
