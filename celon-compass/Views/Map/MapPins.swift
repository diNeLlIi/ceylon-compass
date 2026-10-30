//
//  MapPins.swift
//  celon-compass
//


import SwiftUI

struct MapPinView: View {
    let pin: MapPin

    var body: some View {
        switch pin.kind {
        case let .tripStop(order, _):
            TripStopPin(order: order, name: pin.name, forecast: pin.forecast)
        case let .visited(rating, _):
            VisitedGhostPin(name: pin.name, category: pin.destination?.category, rating: rating)
        case .searchResult:
            SearchResultPin(name: pin.name, forecast: pin.forecast)
        }
    }
}

struct TripStopPin: View {
    let order: Int
    let name: String
    let forecast: DayForecast?

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(AppBrand.tealMid)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    .shadow(radius: 2, y: 1)
                    .overlay {
                        Text("\(order)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }

                if let condition = forecast?.condition {
                    Image(systemName: condition.symbolName)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 17, height: 17)
                        .background(condition.mapPinTint, in: Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .offset(x: 5, y: -4)
                }
            }
            MapPinLabel(text: name)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var label = "Stop \(order), \(name)"
        if let forecast {
            label += ", \(forecast.condition.label), \(Int(forecast.high.rounded())) degrees"
        }
        return label
    }
}

struct VisitedGhostPin: View {
    let name: String
    let category: String?
    let rating: Int16

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
                    .shadow(radius: 1, y: 1)
                    .overlay {
                        Image(systemName: Self.symbol(for: category))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppBrand.heading.opacity(0.55))
                    }

                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 15, height: 15)
                    .background(AppBrand.successSolid, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .offset(x: 3, y: 3)
            }
            MapPinLabel(text: name)
                .opacity(0.65)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var label = "\(name), visited"
        if rating > 0 { label += ", rated \(rating) of 5" }
        return label
    }

    static func symbol(for category: String?) -> String {
        switch category?.lowercased() {
        case "beach": "water.waves"
        case "mountain": "mountain.2.fill"
        case "heritage": "building.columns.fill"
        case "wildlife": "pawprint.fill"
        default: "mappin"
        }
    }
}

struct SearchResultPin: View {
    let name: String
    let forecast: DayForecast?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(AppBrand.amber.opacity(0.5), lineWidth: 2)
                    .frame(width: 36, height: 36)
                    .scaleEffect(isPulsing ? 1.6 : 1)
                    .opacity(isPulsing ? 0 : 1)

                Circle()
                    .fill(AppBrand.amber)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    .shadow(radius: 2, y: 1)
                    .overlay {
                        Image(systemName: forecast?.condition.symbolName ?? "mappin")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppBrand.navy)
                    }
            }
            MapPinLabel(text: name)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), search result")
    }
}

private struct MapPinLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppBrand.heading)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppBrand.card, in: Capsule())
            .overlay(Capsule().stroke(AppBrand.hairline, lineWidth: 0.5))
            .fixedSize()
    }
}

extension WeatherCondition {
    var mapPinTint: Color {
        switch self {
        case .clear: AppBrand.amber
        case .cloudy: AppBrand.tealTop
        case .rain: AppBrand.linkSolid
        case .storm: AppBrand.destructiveSolid
        }
    }
}

#Preview {
    VStack(spacing: 28) {
        TripStopPin(order: 1, name: "Galle Fort", forecast: .previewSample)
        TripStopPin(order: 2, name: "Ella", forecast: nil)
        VisitedGhostPin(name: "Mirissa", category: "Beach", rating: 4)
        SearchResultPin(name: "Yala", forecast: .previewSample)
    }
    .padding(40)
    .background(AppBrand.canvas)
}

private extension DayForecast {
    static let previewSample = DayForecast(
        date: .now, high: 31, low: 24, rainProbability: 20, uvIndex: 8, condition: .rain
    )
}
