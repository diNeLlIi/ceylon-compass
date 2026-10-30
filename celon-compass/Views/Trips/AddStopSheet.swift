//
//  AddStopSheet.swift
//  celon-compass
//
//  Adds a destination or a gem to a trip that already exists. Same action as the
//  map pin's "Add to Trip" control, but reachable from inside the itinerary itself.

import CoreData
import SwiftUI

struct AddStopSheet: View {
    let trip: Itinerary

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Destination.name, ascending: true)])
    private var allDestinations: FetchedResults<Destination>

    @State private var searchText = ""
    @State private var addedIDs: Set<String> = []
    @State private var errorMessage: String?
    @State private var gemPOIs: [POI] = []
    @State private var gemState: GemLoadState = .loading

    private let gemService: OverpassServicing = OverpassService()
    private let radiusKm: Double = 25

    enum GemLoadState: Equatable { case loading, loaded, empty, failed }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    DestinationSearchBar(text: $searchText, prompt: "Search destinations to add")
                        .padding(.horizontal)

                    if !searchText.isEmpty {
                        searchResultsSection
                    } else {
                        gemsSection
                    }
                }
                .padding(.vertical)
            }
            .background(AppBrand.canvas)
            .navigationTitle("Add a Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadGems() }
            .alert(
                "Couldn't add stop",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    //Sections

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Destinations")
                .font(.headline)
                .padding(.horizontal)

            if matchingDestinations.isEmpty {
                Text("No matches for “\(searchText)”.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 10) {
                    ForEach(matchingDestinations) { poi in
                        stopRow(for: poi)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var gemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Gems nearby")
                    .font(.headline)
                Spacer()
                Text("Community")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppBrand.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppBrand.accentTint, in: Capsule())
            }
            .padding(.horizontal)

            switch gemState {
            case .loading:
                gemPlaceholder(
                    symbol: "sparkles",
                    title: "Looking for gems…",
                    message: "Checking OpenStreetMap near your last stop."
                )
            case .empty:
                gemPlaceholder(
                    symbol: "sparkles",
                    title: "No gems within \(Int(radiusKm)) km",
                    message: "Nothing community-mapped sits close by. Try searching for a destination instead."
                )
            case .failed:
                gemPlaceholder(
                    symbol: "wifi.exclamationmark",
                    title: "Couldn't load gems",
                    message: "OpenStreetMap didn't respond.",
                    retry: { Task { await loadGems() } }
                )
            case .loaded:
                VStack(spacing: 10) {
                    ForEach(visibleGems) { poi in
                        stopRow(for: poi)
                    }
                }
                .padding(.horizontal)
            }

            Text("Gem locations via OpenStreetMap contributors")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    private func stopRow(for poi: POI) -> some View {
        StopRow(
            title: poi.name,
            subtitle: poi.category,
            isGem: poi.source == .osm,
            accessory: .toggle(
                isSelected: addedIDs.contains(poi.id),
                onToggle: { add(poi) }
            )
        )
    }

    private func gemPlaceholder(
        symbol: String,
        title: String,
        message: String,
        retry: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(AppBrand.accent)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let retry {
                Button("Try again", action: retry)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(AppBrand.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    //Data

    // The point gems are searched around: the last-dated stop if the trip has one,
    // otherwise the trip's origin.
    private var anchor: Coordinate {
        let stops = ((trip.stops as? Set<ItineraryStop>) ?? [])
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        if let last = stops.last {
            return Coordinate(latitude: last.poiLatitude, longitude: last.poiLongitude)
        }
        return Coordinate(latitude: trip.originLat, longitude: trip.originLon)
    }

    private var existingStopKeys: Set<String> {
        let stops = (trip.stops as? Set<ItineraryStop>) ?? []
        return Set(stops.compactMap { stop -> String? in
            if let id = stop.destination?.id { return "d:\(id.uuidString)" }
            return "p:\(stop.poiLatitude),\(stop.poiLongitude)"
        })
    }

    private func key(for poi: POI) -> String {
        if let id = poi.destination?.id { return "d:\(id.uuidString)" }
        return "p:\(poi.coordinate.latitude),\(poi.coordinate.longitude)"
    }

    private func isAlreadyInTrip(_ poi: POI) -> Bool {
        existingStopKeys.contains(key(for: poi)) || addedIDs.contains(poi.id)
    }

    private var matchingDestinations: [POI] {
        guard !searchText.isEmpty else { return [] }
        return allDestinations
            .filter { ($0.name ?? "").localizedCaseInsensitiveContains(searchText) }
            .map(POI.init(destination:))
            .filter { !isAlreadyInTrip($0) }
    }

    private var visibleGems: [POI] {
        gemPOIs.filter { !isAlreadyInTrip($0) }
    }

    private func loadGems() async {
        gemState = .loading
        do {
            let fetched = try await gemService.gems(alongRoute: anchor, to: anchor, radiusKm: radiusKm, excluding: [])
            gemPOIs = fetched
            gemState = visibleGems.isEmpty ? .empty : .loaded
        } catch {
            gemPOIs = []
            gemState = .failed
        }
    }

    private func add(_ poi: POI) {
        guard !addedIDs.contains(poi.id) else { return }
        let repository = TripRepository(context: context)
        let stopCount = (trip.stops as? Set<ItineraryStop>)?.count ?? 0
        let date = trip.endDate.flatMap { Calendar.current.date(byAdding: .day, value: 1, to: $0) }
            ?? Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        do {
            try repository.addStop(to: trip, poi: poi, date: date, sortIndex: Int16(stopCount))
            trip.startDate = [trip.startDate, date].compactMap { $0 }.min()
            trip.endDate = [trip.endDate, date].compactMap { $0 }.max()
            try context.save()
            addedIDs.insert(poi.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = "Couldn't add this stop. Try again."
        }
    }
}
