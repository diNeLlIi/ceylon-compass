//
//  BestWeatherBentoView.swift
//  celon-compass

import SwiftUI

struct BestWeatherBentoView: View {
    let topPick: Destination
    let runners: [Destination]
    let forecasts: [UUID: [DayForecast]]
    var favouritesStore: FavouritesStore = .shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Best Weather Today", systemImage: "cloud.sun.fill")
                .font(.headline)
                .padding(.horizontal)

            GeometryReader { geo in
                let gap: CGFloat = 8
                let hasRunners = !runners.isEmpty
                let rightWidth = hasRunners ? (geo.size.width - gap) * 0.43 : 0

                HStack(spacing: gap) {
                    NavigationLink(value: topPick) {
                        largeCard(for: topPick)
                    }
                    .buttonStyle(.plain)

                    if hasRunners {
                        VStack(spacing: gap) {
                            ForEach(runners.prefix(2), id: \.id) { destination in
                                NavigationLink(value: destination) {
                                    smallCard(for: destination)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(width: rightWidth)
                    }
                }
            }
            .frame(height: 280)
            .padding(.horizontal)
        }
    }

    private func forecast(for destination: Destination) -> DayForecast? {
        guard let id = destination.id else { return nil }
        return forecasts[id]?.first
    }

    private func largeCard(for destination: Destination) -> some View {
        let fc = forecast(for: destination)
        let id = destination.id ?? UUID()
        let isFav = favouritesStore.isFavourite(id)

        return Color.clear
            .overlay {
                AsyncImage(url: destination.imageURL.flatMap(URL.init(string:))) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Color(.tertiarySystemBackground))
                    }
                }
            }
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .topLeading) {
                HStack(spacing: 5) {
                    Image(systemName: tagIcon(for: destination))
                        .font(.system(size: 10))
                        .foregroundStyle(AppBrand.amber)
                    Text(tagText(for: destination))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    favouritesStore.toggle(id)
                } label: {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isFav ? AppBrand.amber : .white)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(12)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(destination.name ?? "Unknown")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 4) {
                        if let province = destination.province {
                            Text(province)
                        }
                        if destination.province != nil && fc != nil {
                            Text("\u{00B7}")
                        }
                        if let fc {
                            Text("\(Int(fc.high.rounded()))\u{00B0}")
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))

                    if let fc {
                        weatherStrip(fc)
                    }
                }
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func weatherStrip(_ fc: DayForecast) -> some View {
        HStack(spacing: 5) {
            Image(systemName: fc.condition.symbolName)
                .font(.caption2)
            Text("\(Int(fc.high.rounded()))\u{00B0}")
                .font(.caption.weight(.semibold))
            Text("\u{00B7}")
                .font(.caption2)
            Text("\(fc.rainProbability)% rain")
                .font(.caption.weight(.medium))
            Spacer()
            if fc.uvIndex >= 6 {
                HStack(spacing: 3) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 9))
                    Text("UV \(fc.uvIndex)")
                        .font(.system(size: 10, weight: .medium))
                }
            }
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.5), in: Capsule())
    }

    private func smallCard(for destination: Destination) -> some View {
        let fc = forecast(for: destination)
        let id = destination.id ?? UUID()
        let isFav = favouritesStore.isFavourite(id)

        return Color.clear
            .overlay {
                AsyncImage(url: destination.imageURL.flatMap(URL.init(string:))) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Color(.tertiarySystemBackground))
                    }
                }
            }
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.name ?? "Unknown")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let fc {
                        Text("\(Int(fc.high.rounded()))\u{00B0} \u{00B7} \(fc.rainProbability)%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(10)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    favouritesStore.toggle(id)
                } label: {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isFav ? AppBrand.amber : .white.opacity(0.7))
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func tagText(for destination: Destination) -> String {
        switch destination.category?.lowercased() {
        case "beach": return "Warmest Coast"
        case "mountain": return "Cool Highlands"
        case "heritage": return "Ancient Wonder"
        case "wildlife": return "Safari Ready"
        default: return "Top Pick"
        }
    }

    private func tagIcon(for destination: Destination) -> String {
        switch destination.category?.lowercased() {
        case "beach": return "sun.max.fill"
        case "mountain": return "mountain.2.fill"
        case "heritage": return "building.columns.fill"
        case "wildlife": return "pawprint.fill"
        default: return "star.fill"
        }
    }
}
