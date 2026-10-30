//
//  CompareShareCardView.swift
//  celon-compass
//
//

import SwiftUI

struct CompareShareCardView: View {
    let window: BestWindow?
    let ranked: [(destination: Destination, score: DestinationWeatherScore)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("WANDERLANKA")
                    .font(.caption.weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(AppBrand.accentStrong)
                Text("Travel window")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppBrand.heading)
            }

            if let window, let first = window.days.first, let last = window.days.last {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateRange(first: first, last: last))
                        .font(.title.weight(.bold))
                        .foregroundStyle(AppBrand.heading)
                    Text(window.isAllClear ? "Clear across all destinations" : "Low rain risk across destinations")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppBrand.accentTint, in: RoundedRectangle(cornerRadius: 16))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("RANKED")
                    .font(.caption.weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(.secondary)
                ForEach(Array(ranked.enumerated()), id: \.offset) { pair in
                    row(rank: pair.offset + 1, destination: pair.element.destination, score: pair.element.score)
                }
            }

            Spacer()

            Text("Planned with WanderLanka")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(width: 1080, height: 1350)
        .background(AppBrand.canvas)
        .environment(\.colorScheme, .light)
    }

    private func row(rank: Int, destination: Destination, score: DestinationWeatherScore) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(bandColor(score.band))
                .frame(width: 36, height: 36)
                .overlay {
                    Text("\(rank)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(destination.name ?? "Unknown")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppBrand.heading)
                Text(score.band.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(score.score)")
                .font(.title.weight(.bold))
                .foregroundStyle(bandColor(score.band))
        }
        .padding(12)
        .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func dateRange(first: Date, last: Date) -> String {
        let start = first.formatted(.dateTime.weekday(.abbreviated).day())
        let end = last.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return "\(start) – \(end)"
    }

    private func bandColor(_ band: Band) -> Color {
        switch band {
        case .ideal: return AppBrand.successSolid
        case .good: return AppBrand.amber
        case .fair: return AppBrand.tealTop  
        }
    }
}
