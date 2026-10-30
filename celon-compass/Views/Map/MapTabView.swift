//
//  MapTabView.swift
//  celon-compass
//
//  Shows only the user's own places: stops on the active trip and destinations they
//  have visited. The full catalog stays off the map and is reached through search

import SwiftUI
import MapKit
import CoreData

struct MapTabView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Destination.name, ascending: true)]
    )
    private var destinations: FetchedResults<Destination>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Itinerary.startDate, ascending: true)]
    )
    private var trips: FetchedResults<Itinerary>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VisitRecord.visitDate, ascending: false)]
    )
    private var visits: FetchedResults<VisitRecord>

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.isRegularWidth) private var isRegularWidth

    @State private var position: MapCameraPosition = .region(Self.sriLanka)
    @State private var visibleRegion: MKCoordinateRegion = Self.sriLanka
    @State private var mapStyle: MapStyleChoice = .standard
    @State private var selectedPinID: String?
    @State private var searchResult: Destination?
    @State private var searchText = ""
    @State private var forecasts: [UUID: [DayForecast]] = [:]
    @State private var isLoadingWeather = false
    @State private var gemPOIs: [POI] = []
    @State private var selectedGem: POI?
    @State private var gemLoadTask: Task<Void, Never>?
    @State private var mapSearchResults: [MKMapItem] = []
    @State private var mapSearchTask: Task<Void, Never>?

    private let weatherService: WeatherServicing = WeatherService()
    private let gemService: OverpassServicing = OverpassService()

    private static let sriLanka = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 7.8731, longitude: 80.7718),
        span: MKCoordinateSpan(latitudeDelta: 3.4, longitudeDelta: 3.2)
    )

    private var activeTrip: Itinerary? { ActiveTripResolver.current(Array(trips)) }

    private var tripStops: [ItineraryStop] { MapPinBuilder.sortedStops(of: activeTrip) }

    private var pins: [MapPin] {
        MapPinBuilder.pins(
            tripStops: tripStops,
            visits: Array(visits),
            searchResult: searchResult,
            forecasts: forecasts
        )
    }

    private var tripRouteCoordinates: [CLLocationCoordinate2D] {
        tripStops.map { CLLocationCoordinate2D(latitude: $0.poiLatitude, longitude: $0.poiLongitude) }
    }

    private var selectedPin: Binding<MapPin?> {
        Binding(
            get: { pins.first { $0.id == selectedPinID } },
            set: { selectedPinID = $0?.id }
        )
    }

    private var searchMatches: [Destination] {
        guard !searchText.isEmpty else { return [] }
        return destinations.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isRegularWidth {
                    
                    HStack(spacing: 0) {
                        tripStopList
                            .frame(width: 320)
                        Divider()
                        mapSurface
                    }
                } else {
                    mapSurface
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .brandToolbar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    styleToggle
                }
            }
            .task {
                try? VisitLogger(context: viewContext).backfillFromPastTrips()
                await loadWeatherIfNeeded()
                scheduleGemFetch()
            }
            .sheet(item: selectedPin) { pin in
                NavigationStack {
                    MapPinSheet(pin: pin)
                        // The map opens the trip, not the catalog entry: DestinationDetailView
                        // carries a "Plan a Trip Here" CTA that belongs to Explore.
                        .navigationDestination(for: Itinerary.self) { trip in
                            ItineraryView(trip: trip)
                        }
                }
                .presentationDetents([.height(300), .medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedGem) { gem in
                GemQuickSheet(gem: gem)
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private var tripStopList: some View {
        if tripStops.isEmpty {
            ContentUnavailableView(
                "No active trip",
                systemImage: "map",
                description: Text("Plan a trip from Explore and its stops appear here.")
            )
        } else {
            List {
                Section(activeTrip?.title ?? "Trip") {
                    ForEach(Array(tripStops.enumerated()), id: \.element.objectID) { index, stop in
                        Button {
                            focus(on: stop)
                        } label: {
                            StopRow(
                                title: stop.poiName ?? "Unknown",
                                time: stop.date?.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)),
                                forecast: forecast(for: stop),
                                isGem: stop.poiSource == POI.Source.osm.rawValue
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            selectedPinID == stop.id?.uuidString ? AppBrand.accentTint : Color.clear
                        )
                        .accessibilityHint("Stop \(index + 1). Centres the map on this stop.")
                    }
                }
            }
            .listStyle(.plain)
            .background(AppBrand.canvas)
        }
    }

    private func forecast(for stop: ItineraryStop) -> DayForecast? {
        guard let id = stop.destination?.id, let date = stop.date else { return nil }
        return forecasts[id]?.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func focus(on stop: ItineraryStop) {
        selectedPinID = stop.id?.uuidString
        withAnimation {
            position = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: stop.poiLatitude, longitude: stop.poiLongitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
            )
        }
    }

    private var mapSurface: some View {
        Map(position: $position) {
                ForEach(pins) { pin in
                    Annotation(pin.name, coordinate: pin.coordinate) {
                        MapPinView(pin: pin)
                            .onTapGesture { selectedPinID = pin.id }
                    }
                }

                ForEach(gemPOIs) { gem in
                    Annotation(gem.name, coordinate: CLLocationCoordinate2D(latitude: gem.coordinate.latitude, longitude: gem.coordinate.longitude)) {
                        GemPin()
                            .onTapGesture { selectedGem = gem }
                            .accessibilityLabel("\(gem.name), \(gem.category ?? "point of interest"), community gem")
                    }
                }

                if tripRouteCoordinates.count >= 2 {
                    MapPolyline(coordinates: tripRouteCoordinates)
                        .stroke(AppBrand.tealMid, lineWidth: 4)
                }
            }
            .mapStyle(mapStyle.swiftUIStyle)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
                scheduleGemFetch()
            }
            .overlay(alignment: .center) { emptyStateCard }
            .overlay(alignment: .bottom) { searchOverlay }
    }

    @ViewBuilder
    private var emptyStateCard: some View {
        if pins.isEmpty && !isLoadingWeather {
            VStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.title)
                    .foregroundStyle(AppBrand.accent)
                Text("Nothing on your map yet")
                    .font(.headline)
                    .foregroundStyle(AppBrand.heading)
                Text("Stops on your trips and places you've visited show up here. Search to find somewhere to start.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: 280)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppBrand.hairline, lineWidth: 0.5))
            .shadow(radius: 8, y: 2)
        }
    }

    private var hasAnyResults: Bool {
        !searchMatches.isEmpty || !mapSearchResults.isEmpty
    }

    // Positioned like Explore's search bar: floating at the bottom of the screen,
    // not pinned above the content, so the map itself stays the full canvas.
    private var searchOverlay: some View {
        VStack(spacing: 8) {
            if hasAnyResults {
                searchResultsList
            }
            gemAttribution
            DestinationSearchBar(text: $searchText, prompt: "Search any place in Sri Lanka")
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .onChange(of: searchText) { _, newValue in
            scheduleMapSearch(for: newValue)
        }
    }

    private var searchResultsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(searchMatches.prefix(3).enumerated()), id: \.element.objectID) { index, destination in
                Button {
                    selectSearchResult(destination)
                } label: {
                    DestinationSearchRow(destination: destination)
                }
                .buttonStyle(.plain)
                if index < min(searchMatches.count, 3) - 1 || !mapSearchResults.isEmpty {
                    Divider().padding(.leading, 70)
                }
            }

            let mapItems = mapSearchResults.prefix(5 - min(searchMatches.count, 3))
            ForEach(Array(mapItems.enumerated()), id: \.offset) { index, item in
                Button {
                    selectMapItem(item)
                } label: {
                    MapSearchRow(item: item)
                }
                .buttonStyle(.plain)
                if index < mapItems.count - 1 {
                    Divider().padding(.leading, 70)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppBrand.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }

    @ViewBuilder
    private var gemAttribution: some View {
        // Shown whenever gem pins are on screen, searching or not — ODbL attribution is a
        // licence condition, not a cosmetic caption that can be hidden to save space.
        if !gemPOIs.isEmpty {
            Text("Gem locations via OpenStreetMap contributors")
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private func selectSearchResult(_ destination: Destination) {
        searchText = ""
        mapSearchResults = []
        withAnimation {
            position = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
                )
            )
        }
        guard let id = destination.id else { return }
        if let existing = pins.first(where: { $0.destination?.id == id }) {
            selectedPinID = existing.id
        } else {
            searchResult = destination
            selectedPinID = "search-\(id.uuidString)"
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func selectMapItem(_ item: MKMapItem) {
        searchText = ""
        mapSearchResults = []
        let coord = item.placemark.coordinate
        withAnimation {
            position = .region(
                MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            )
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func scheduleMapSearch(for query: String) {
        mapSearchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            mapSearchResults = []
            return
        }
        mapSearchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = Self.sriLanka
            let search = MKLocalSearch(request: request)
            let response = try? await search.start()
            guard !Task.isCancelled else { return }
            let catalogNames = Set(searchMatches.prefix(3).compactMap { $0.name?.lowercased() })
            mapSearchResults = (response?.mapItems ?? []).filter { item in
                guard let name = item.name?.lowercased() else { return true }
                return !catalogNames.contains(name)
            }
        }
    }

    private var styleToggle: some View {
        Button {
            mapStyle = mapStyle.next
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Image(systemName: mapStyle.toggleSymbol)
                .foregroundStyle(AppBrand.accentStrong)
                .padding(8)
                .background(AppBrand.card.opacity(0.9), in: Circle())
                .overlay(Circle().stroke(AppBrand.hairline, lineWidth: 0.5))
        }
        .accessibilityLabel("Switch map style")
    }

    private func scheduleGemFetch() {
        gemLoadTask?.cancel()
        let radiusKm = min(25, max(3, visibleRegion.span.latitudeDelta * 55))
        let center = Coordinate(
            latitude: (visibleRegion.center.latitude * 100).rounded() / 100,
            longitude: (visibleRegion.center.longitude * 100).rounded() / 100
        )
        gemLoadTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            let fetched = try? await gemService.gems(alongRoute: center, to: center, radiusKm: radiusKm, excluding: [])
            guard !Task.isCancelled else { return }
            gemPOIs = fetched ?? []
        }
    }

    
    @MainActor
    private func loadWeatherIfNeeded() async {
        guard !isLoadingWeather, forecasts.isEmpty, !destinations.isEmpty else { return }
        isLoadingWeather = true
        defer { isLoadingWeather = false }
        do {
            forecasts = try await weatherService.forecasts(for: Array(destinations))
        } catch {
            // Non-fatal: pins fall back to the muted "no weather" variant.
            forecasts = [:]
        }
    }
}

enum MapStyleChoice: String, CaseIterable {
    case standard, imagery, hybrid

    var next: MapStyleChoice {
        let all = Self.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }

    var toggleSymbol: String {
        switch self {
        case .standard: return "map.fill"
        case .imagery: return "globe.americas.fill"
        case .hybrid: return "square.stack.3d.up.fill"
        }
    }

    var swiftUIStyle: MapStyle {
        switch self {
        case .standard: return .standard(elevation: .realistic)
        case .imagery: return .imagery(elevation: .realistic)
        case .hybrid: return .hybrid(elevation: .realistic)
        }
    }
}

struct GemPin: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AppBrand.amber)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(radius: 2, y: 1)
            Image(systemName: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppBrand.navy)
        }
    }
}

struct MapSearchRow: View {
    let item: MKMapItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(AppBrand.accent)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name ?? "Unknown")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppBrand.heading)
                if let locality = item.placemark.locality ?? item.placemark.administrativeArea {
                    Text(locality)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

#Preview {
    MapTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
