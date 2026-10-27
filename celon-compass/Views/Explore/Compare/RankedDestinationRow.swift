//
//  RankedDestinationRow.swift
//  celon-compass
//

import SwiftUI
import CoreData

struct RankedDestinationRow: View {
    let rank: Int
    let destination: Destination
    let score: DestinationWeatherScore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(destination.name ?? "Unknown")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppBrand.navy)
                        bandPill
                        Spacer(minLength: 0)
                    }
                    metricRow
                }
                Spacer(minLength: 0)
                Text("\(score.score)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(bandColor)
                    .accessibilityHidden(true)
            }

            progressBar
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(rank == 1 ? AppBrand.tealTop.opacity(0.45) : Color(.separator).opacity(0.4),
                        lineWidth: rank == 1 ? 1.5 : 1)
        )
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(rank), \(destination.name ?? "destination"), \(score.band.displayName), score \(score.score) of 100")
    }

    private var thumbnail: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 60, height: 60)
                .overlay {
                    if let url = destination.imageURL.flatMap(URL.init(string:)) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "mountain.2.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            Circle()
                .fill(bandColor)
                .frame(width: 22, height: 22)
                .overlay {
                    Text("\(rank)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }
                .offset(x: -6, y: -6)
        }
    }

    private var bandPill: some View {
        HStack(spacing: 4) {
            Image(systemName: score.band.systemImage)
                .font(.caption2)
            Text(score.band.displayName)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(bandColor.opacity(0.15), in: Capsule())
        .foregroundStyle(bandColor)
    }

    private var metricRow: some View {
        HStack(spacing: 10) {
            metric(symbol: "sun.max", value: "\(Int(score.avgHigh.rounded()))° avg")
            metric(symbol: "drop.fill", value: "\(score.avgRainPct)% rain")
            metric(symbol: "cloud.sun.fill", value: String(format: "%.1fh sun", score.avgSunHours))
        }
    }

    private func metric(symbol: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.caption2)
            Text(value)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.secondarySystemBackground))
                Capsule()
                    .fill(bandColor)
                    .frame(width: max(12, proxy.size.width * CGFloat(score.score) / 100))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    private var bandColor: Color {
        switch score.band {
        case .ideal: return AppBrand.success
        case .good: return AppBrand.amber
        case .fair: return AppBrand.tealTop
        }
    }
}

#Preview("Ranked rows") {
    let context = PersistenceController.preview.container.viewContext

    let mirissa = Destination(context: context)
    mirissa.id = UUID()
    mirissa.name = "Mirissa"
    mirissa.imageURL = nil

    let sigiriya = Destination(context: context)
    sigiriya.id = UUID()
    sigiriya.name = "Sigiriya"

    let ella = Destination(context: context)
    ella.id = UUID()
    ella.name = "Ella"

    return VStack(spacing: 10) {
        RankedDestinationRow(
            rank: 1, destination: mirissa,
            score: DestinationWeatherScore(destinationId: mirissa.id!, score: 92, band: .ideal,
                                           avgHigh: 30, avgRainPct: 8, avgSunHours: 6.8, evaluatedDayCount: 5)
        )
        RankedDestinationRow(
            rank: 2, destination: sigiriya,
            score: DestinationWeatherScore(destinationId: sigiriya.id!, score: 78, band: .good,
                                           avgHigh: 32, avgRainPct: 17, avgSunHours: 5.9, evaluatedDayCount: 5)
        )
        RankedDestinationRow(
            rank: 3, destination: ella,
            score: DestinationWeatherScore(destinationId: ella.id!, score: 64, band: .fair,
                                           avgHigh: 25, avgRainPct: 24, avgSunHours: 4.4, evaluatedDayCount: 5)
        )
    }
    .padding(.vertical)
    .background(AppBrand.canvas)
}
