//
//  RecommendedWindowCard.swift
//  celon-compass
//

import SwiftUI

struct RecommendedWindowCard: View {
    let bestWindow: BestWindow?
    let maxRainPct: Int?
    let destinationCount: Int
    let shareImage: Image?
    let onPlan: () -> Void

    @State private var planTapCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let bestWindow, let first = bestWindow.days.first, let last = bestWindow.days.last {
                dateHeadline(first: first, last: last)
                Text(summarySentence(bestWindow: bestWindow))
                    .font(.subheadline)
                    .foregroundStyle(AppBrand.heading.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                actionRow
            } else {
                Text("No shared window in this range — try 2 weeks or remove a destination.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppBrand.accent.opacity(0.55), lineWidth: 1.5)
        )
        .padding(.horizontal)
    }

    private var header: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppBrand.accentTint)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(AppBrand.accentStrong)
                }
            Text("RECOMMENDED WINDOW")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(AppBrand.accentStrong)
            Spacer()
        }
    }

    private func dateHeadline(first: Date, last: Date) -> some View {
        Text(headlineRange(first: first, last: last))
            .font(.title2.weight(.bold))
            .foregroundStyle(AppBrand.heading)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                planTapCount += 1
                onPlan()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text("Plan these dates")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppBrand.tealMid, in: Capsule())
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens a sheet to create a trip for these dates")
            .sensoryFeedback(.impact(weight: .medium), trigger: planTapCount)

            if let image = shareImage {
                ShareLink(
                    item: image,
                    preview: SharePreview("Travel window", image: image)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(AppBrand.accentStrong)
                        .padding(12)
                        .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Share recommended window")
            }
        }
    }

    private func summarySentence(bestWindow: BestWindow) -> String {
        let n = destinationCount
        let rainClause: String
        if let maxRainPct {
            let rounded = roundTo5(maxRainPct)
            rainClause = "rain chance under \(rounded)%"
        } else {
            rainClause = "low rain risk"
        }
        if bestWindow.isAllClear {
            return "Clear at all \(n) destinations, with \(rainClause)."
        }
        return "Mostly clear across the \(n) destinations, with \(rainClause)."
    }

    private func headlineRange(first: Date, last: Date) -> String {
        if Calendar.current.isDate(first, inSameDayAs: last) {
            return first.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
        let start = first.formatted(.dateTime.weekday(.abbreviated).day())
        let end = last.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return "\(start) – \(end)"
    }

    private func roundTo5(_ value: Int) -> Int {
        let rounded = (Double(value) / 5.0).rounded(.up) * 5
        return Int(rounded)
    }
}

#Preview("With window") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let days = [2, 3, 4].compactMap { calendar.date(byAdding: .day, value: $0, to: today) }

    return VStack(spacing: 20) {
        RecommendedWindowCard(
            bestWindow: BestWindow(days: days, score: 12, isAllClear: true),
            maxRainPct: 12,
            destinationCount: 3,
            shareImage: nil,
            onPlan: {}
        )

        RecommendedWindowCard(
            bestWindow: nil,
            maxRainPct: nil,
            destinationCount: 2,
            shareImage: nil,
            onPlan: {}
        )
    }
    .padding(.vertical)
    .background(AppBrand.canvas)
}
