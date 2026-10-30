//
//  MapTabView.swift
//  celon-compass
//
//  Shows only the user's own places: stops on the active trip and destinations they
//  have visited. The full catalog stays off the map and is reached through search

import SwiftUI
import MapKit
public import CoreData

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

    @State private var position: MapCameraPosition = .region(Self.sriLanka)
    @State private var visibleRegion: MKCoordinateRegion = Self.sriLanka
    @State private var mapStyle: MapStyleChoice = .standard
    @State private var selectedPinID: String?
    @State private var searchResult: Destination?
    @State private var forecasts: [UUID: [DayForecast]] = [:]
    @State private var isLoadingWeather = false
    @State private var gemPOIs: [POI] = []
    @State private var gemLoadTask: Task<Void, Never>?

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

    var body: some View {
        NavigationStack {
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
            .overlay(alignment: .bottom) { gemAttribution }
            .ignoresSafeArea(.container, edges: .bottom)
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
        }
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

    @ViewBuilder
    private var gemAttribution: some View {
        if !gemPOIs.isEmpty {
            Text("Gem locations via OpenStreetMap contributors")
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 8)
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

#Preview {
    MapTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
