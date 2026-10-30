//
//  NextStopEntryView.swift
//  WanderLankaWidget
//

import SwiftUI
import WidgetKit

struct NextStopEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextStopEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            lockScreen
        case .systemMedium:
            medium
        default:
            small
        }
    }

    private var link: URL {
        guard let tripID = entry.next?.tripID else { return DeepLink.trips.url }
        return DeepLink.trip(tripID).url
    }

    // Small: next stop only — name, glyph, temperature.

    @ViewBuilder
    private var small: some View {
        if let stop = entry.next {
            VStack(alignment: .leading, spacing: 6) {
                Text(stop.date, format: .dateTime.weekday(.wide))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(stop.name)
                    .font(.headline)
                    .foregroundStyle(AppBrand.heading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Image(systemName: stop.conditionSymbol)
                        .font(.title3)
                        .foregroundStyle(AppBrand.accent)
                        .symbolRenderingMode(.hierarchical)
                    Text(stop.temperatureText)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppBrand.heading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(link)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Next stop \(stop.name), \(stop.conditionLabel), \(stop.temperatureText)")
        } else {
            emptyState
        }
    }

    // Medium: the next three stops.

    @ViewBuilder
    private var medium: some View {
        if entry.stops.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Next stops")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                ForEach(entry.stops.prefix(3)) { stop in
                    HStack(spacing: 10) {
                        Image(systemName: stop.conditionSymbol)
                            .font(.subheadline)
                            .foregroundStyle(AppBrand.accent)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(stop.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppBrand.heading)
                                .lineLimit(1)
                            Text(stop.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Text(stop.temperatureText)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppBrand.heading)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(stop.name), \(stop.conditionLabel), \(stop.temperatureText)")
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(link)
        }
    }

    // Lock Screen: rendered monochrome, so meaning has to come from glyph and weight
    // rather than colour. No AppBrand tints here on purpose.

    @ViewBuilder
    private var lockScreen: some View {
        if let stop = entry.next {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: stop.conditionSymbol)
                        .font(.caption)
                    Text(stop.temperatureText)
                        .font(.caption.weight(.bold))
                    Text(stop.date, format: .dateTime.weekday(.abbreviated))
                        .font(.caption)
                }
                Text(stop.name)
                    .font(.headline)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(link)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Next stop \(stop.name), \(stop.conditionLabel), \(stop.temperatureText)")
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("WanderLanka")
                    .font(.caption.weight(.bold))
                Text("No trip planned")
                    .font(.headline)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(DeepLink.trips.url)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "suitcase")
                .font(.title3)
                .foregroundStyle(AppBrand.accent)
            Text("No trip planned")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppBrand.heading)
            Text("Plan one in WanderLanka to see your next stop here.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(DeepLink.trips.url)
    }
}
