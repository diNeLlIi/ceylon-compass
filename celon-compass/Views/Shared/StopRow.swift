//
//  StopRow.swift
//  celon-compass
//
//  One stop in a timeline 
//

import SwiftUI

struct StopRow: View {
    enum Accessory {
        case toggle(isSelected: Bool, onToggle: () -> Void)
        case dragHandle
        case none
    }

    enum ConflictSeverity {
        case none, caution, severe
    }

    let title: String
    var time: String?
    var subtitle: String?
    var note: String?
    var imageURL: URL?
    var forecast: DayForecast?
    var forecastUnavailableLabel: String?
    var detailedForecast: Bool = false
    var isGem: Bool = false
    var conflictSeverity: ConflictSeverity = .none
    var accessory: Accessory = .none

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if isGem {
                        Text("GEM")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppBrand.navy)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppBrand.amber.opacity(0.35), in: Capsule())
                    }
                    if let time {
                        Text(time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let forecast {
                    WeatherBadgeView(forecast: forecast, style: .onSurface, detailed: detailedForecast)
                } else if let forecastUnavailableLabel {
                    Text(forecastUnavailableLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(conflictSeverity == .severe ? AppBrand.destructive : .secondary)
                }

                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            accessoryView
        }
        .padding(10)
        .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            switch conflictSeverity {
            case .severe:
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppBrand.destructive, lineWidth: 1.5)
            case .caution:
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppBrand.amber, lineWidth: 1.5)
            case .none:
                EmptyView()
            }
        }
    }

    private var thumbnail: some View {
        Color.clear
            .frame(width: 52, height: 52)
            .overlay {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Rectangle().fill(Color(.tertiarySystemBackground))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .none:
            EmptyView()
        case .dragHandle:
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        case .toggle(let isSelected, let onToggle):
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark" : "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        isSelected ? AppBrand.tealTop : Color(.secondarySystemBackground),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    let clearForecast = DayForecast(date: .now, high: 30, low: 24, rainProbability: 5, uvIndex: 8, condition: .clear)
    let stormForecast = DayForecast(date: .now, high: 22, low: 18, rainProbability: 80, uvIndex: 2, condition: .storm)

    return ScrollView {
        VStack(spacing: 10) {
            StopRow(
                title: "Galle Fort",
                subtitle: "Heritage · 8 km off route",
                forecast: clearForecast,
                accessory: .toggle(isSelected: true, onToggle: {})
            )
            StopRow(
                title: "Madu River",
                subtitle: "Wildlife · 12 km off route",
                forecast: stormForecast,
                accessory: .toggle(isSelected: false, onToggle: {})
            )
            StopRow(
                title: "Hiyare Rainforest",
                subtitle: "Waterfall · 4.2 km from route",
                isGem: true,
                accessory: .toggle(isSelected: false, onToggle: {})
            )
            StopRow(
                title: "Mirissa",
                time: "6:30 am",
                note: "Whale boat leaves from the harbour",
                forecast: clearForecast,
                accessory: .dragHandle
            )
            StopRow(
                title: "Ella",
                time: "6:40 am",
                note: "Nine Arch Bridge before the crowds",
                forecast: stormForecast,
                detailedForecast: true,
                conflictSeverity: .severe,
                accessory: .dragHandle
            )
            StopRow(title: "Yala", subtitle: "Wildlife")
        }
        .padding()
    }
}
