//
//  PlanTripView.swift
//  celon-compass
//

//

import SwiftUI
import CoreData

struct PlanTripView: View {
    @StateObject private var viewModel: PlanTripViewModel
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showItinerary = false

    init(destination: Destination) {
        _viewModel = StateObject(wrappedValue: PlanTripViewModel(destination: destination))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                routeHeader
                RadiusSliderView(
                    initialValue: viewModel.committedRadiusKm,
                    range: 5...50,
                    placesInRange: viewModel.stopsWithinRadius.count,
                    onCommit: viewModel.commitRadius
                )
                .padding(.horizontal)

                stopsSection
                gemsSection
            }
            .padding(.vertical)
            .padding(.bottom, 90)
        }
        .background(AppBrand.canvas)
        .navigationTitle("Plan a Trip")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .safeAreaInset(edge: .bottom) { createItineraryBar }
        .navigationDestination(isPresented: $showItinerary) {
            if let trip = viewModel.createdTrip {
                ItineraryView(trip: trip)
            }
        }
        .alert(
            "Trip not created",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var routeHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 2) {
                        Circle()
                            .strokeBorder(Color.secondary, lineWidth: 1.5)
                            .frame(width: 10, height: 10)
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: 1.5, height: 28)
                        Circle()
                            .fill(AppBrand.tealTop)
                            .frame(width: 10, height: 10)
                    }
                    .padding(.top, 3)

                    VStack(alignment: .leading, spacing: 14) {
                        routePoint(label: "FROM", name: viewModel.originName)
                        routePoint(label: "TO", name: viewModel.destination.name ?? "Unknown")
                    }
                }
                Spacer()
                destinationWeatherBadge
            }

            HStack(spacing: 8) {
                statChip(systemImage: "map", text: distanceText)
                statChip(systemImage: "clock", text: durationText)
                statChip(systemImage: "calendar", text: viewModel.tripStartDate.formatted(.dateTime.month(.abbreviated).day()))
            }
        }
        .padding()
        .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    private func routePoint(label: String, name: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(name)
                .font(.headline)
        }
    }

    @ViewBuilder
    private var destinationWeatherBadge: some View {
        if let forecast = viewModel.forecasts[viewModel.destination.id ?? UUID()]?.first {
            VStack(spacing: 2) {
                Image(systemName: forecast.condition.symbolName)
                    .font(.title3)
                    .foregroundStyle(AppBrand.tealTop)
                    .symbolRenderingMode(.hierarchical)
                Text("\(Int(forecast.high.rounded()))°")
                    .font(.subheadline.weight(.bold))
                Text(forecast.condition.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statChip(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground), in: Capsule())
    }

    private var distanceText: String {
        "\(Int(viewModel.routeEstimate.distanceKm.rounded())) km"
    }

    private var durationText: String {
        let hours = Int(viewModel.routeEstimate.duration / 3600)
        let minutes = Int((viewModel.routeEstimate.duration.truncatingRemainder(dividingBy: 3600)) / 60)
        return hours > 0 ? "\(hours) h \(minutes) m" : "\(minutes) m"
    }

    private var stopsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Stops along the way")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.selectedPOIIDs.count) of \(viewModel.stopsWithinRadius.count) added")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            if viewModel.stopsWithinRadius.isEmpty {
                Text("No catalog destinations within \(Int(viewModel.committedRadiusKm)) km of this route.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.stopsWithinRadius.enumerated()), id: \.element.id) { index, poi in
                        HStack(alignment: .top, spacing: 10) {
                            timelineMarker(index: index, isLast: index == viewModel.stopsWithinRadius.count - 1)
                            StopRow(
                                title: poi.name,
                                subtitle: subtitle(for: poi),
                                forecast: viewModel.forecast(for: poi),
                                isGem: poi.source == .osm,
                                accessory: .toggle(
                                    isSelected: viewModel.isSelected(poi),
                                    onToggle: { viewModel.toggle(poi) }
                                )
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func subtitle(for poi: POI) -> String {
        let distance = RouteCorridor.offRouteDistanceKm(point: poi.coordinate, from: viewModel.origin, to: viewModel.destinationCoordinate)
        let category = poi.category ?? "Place"
        return "\(category) · \(Int(distance.rounded())) km off route"
    }

    private func timelineMarker(index: Int, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(AppBrand.tealTop, in: Circle())
            if !isLast {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
            }
        }
        .padding(.top, 10)
    }

    private var gemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Gems along the way")
                    .font(.headline)
                Spacer()
                Text("Community")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppBrand.tealTop)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppBrand.tealTop.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal)

            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(AppBrand.tealTop)
                Text("No gems yet")
                    .font(.subheadline.weight(.semibold))
                Text("Community-sourced spots along this route are coming soon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal)

            Text("Gem locations via OpenStreetMap contributors")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    private var createItineraryBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(viewModel.selectedStops.count + 1) stops selected")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(distanceText) · \(durationText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                if viewModel.createItinerary(context: context) != nil {
                    showItinerary = true
                }
            } label: {
                HStack {
                    Text("Create itinerary")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppBrand.tealTop, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let destination = Destination(context: context)
    destination.id = UUID()
    destination.name = "Mirissa"
    destination.latitude = 5.9483
    destination.longitude = 80.4588

    return NavigationStack {
        PlanTripView(destination: destination)
    }
    .environment(\.managedObjectContext, context)
}
