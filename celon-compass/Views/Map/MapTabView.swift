//
//  MapTabView.swift
//  celon-compass
//

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

    @State private var position: MapCameraPosition = .region(Self.sriLanka)
    @State private var visibleRegion: MKCoordinateRegion = Self.sriLanka
    @State private var mapStyle: MapStyleChoice = .standard
    @State private var selected: Destination?
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

    private var visibleDestinations: [Destination] {
        destinations.filter { isVisible(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) }
    }

    private var activeTripRouteCoordinates: [CLLocationCoordinate2D] {
        guard let trip = ActiveTripResolver.current(Array(trips)) else { return [] }
        let stops = ((trip.stops as? Set<ItineraryStop>) ?? [])
            .sorted {
                if $0.date != $1.date { return ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
                return $0.sortOrder < $1.sortOrder
            }
        return stops.map { CLLocationCoordinate2D(latitude: $0.poiLatitude, longitude: $0.poiLongitude) }
    }

    var body: some View {
        NavigationStack {
            Map(position: $position, selection: $selected) {
                ForEach(Array(visibleDestinations), id: \.self) { destination in
                    Annotation(
                        destination.name ?? "Destination",
                        coordinate: CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
                    ) {
                        WeatherPin(forecast: destinationForecast(destination))
                            .onTapGesture { selected = destination }
                    }
                    .tag(destination)
                }

                ForEach(gemPOIs) { gem in
                    Annotation(gem.name, coordinate: CLLocationCoordinate2D(latitude: gem.coordinate.latitude, longitude: gem.coordinate.longitude)) {
                        GemPin()
                    }
                }

                if activeTripRouteCoordinates.count >= 2 {
                    MapPolyline(coordinates: activeTripRouteCoordinates)
                        .stroke(.primary, lineWidth: 4)
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
            .overlay(alignment: .bottom) {
                if !gemPOIs.isEmpty {
                    Text("Gem locations via OpenStreetMap contributors")
                        .font(.caption2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 8)
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    styleToggle
                }
            }
            .task {
                await loadWeatherIfNeeded()
                scheduleGemFetch()
            }
            .sheet(item: $selected) { destination in
                NavigationStack {
                    DestinationQuickSheet(
                        destination: destination,
                        forecast: destinationForecast(destination)
                    )
                    .navigationDestination(for: Destination.self) { d in
                        DestinationDetailView(
                            destination: d,
                            forecasts: forecasts[d.id ?? UUID()] ?? []
                        )
                    }
                }
                .presentationDetents([.height(260), .medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var styleToggle: some View {
        Button {
            mapStyle = mapStyle.next
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Image(systemName: mapStyle.toggleSymbol)
                .foregroundStyle(AppBrand.navy)
                .padding(8)
                .background(AppBrand.card.opacity(0.9), in: Circle())
                .overlay(Circle().stroke(Color(.separator), lineWidth: 0.5))
        }
        .accessibilityLabel("Switch map style")
    }

    private func destinationForecast(_ destination: Destination) -> DayForecast? {
        guard let id = destination.id else { return nil }
        return forecasts[id]?.first
    }

    private func isVisible(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let latDelta = visibleRegion.span.latitudeDelta / 2
        let lonDelta = visibleRegion.span.longitudeDelta / 2
        let latRange = (visibleRegion.center.latitude - latDelta)...(visibleRegion.center.latitude + latDelta)
        let lonRange = (visibleRegion.center.longitude - lonDelta)...(visibleRegion.center.longitude + lonDelta)
        return latRange.contains(coordinate.latitude) && lonRange.contains(coordinate.longitude)
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
        let list = Array(destinations)
        do {
            forecasts = try await weatherService.forecasts(for: list)
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

private struct WeatherPin: View {
    let forecast: DayForecast?

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(radius: 2, y: 1)
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
            if let temp = forecast.map({ "\(Int($0.high.rounded()))°" }) {
                Text(temp)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppBrand.card, in: Capsule())
                    .overlay(Capsule().stroke(Color(.separator), lineWidth: 0.5))
                    .foregroundStyle(AppBrand.navy)
            }
        }
    }

    private var symbol: String {
        forecast?.condition.symbolName ?? "mappin"
    }

    private var backgroundColor: Color {
        guard let condition = forecast?.condition else { return .secondary }
        switch condition {
        case .clear: return AppBrand.amber
        case .cloudy: return AppBrand.tealTop
        case .rain: return AppBrand.link
        case .storm: return AppBrand.destructive
        }
    }
}

private struct GemPin: View {
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

private struct DestinationQuickSheet: View {
    let destination: Destination
    let forecast: DayForecast?

    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Itinerary.startDate, ascending: true)]
    )
    private var allTrips: FetchedResults<Itinerary>

    @State private var showTripPicker = false
    @State private var showPlanTrip = false
    @State private var addedTripTitle: String?
    @State private var errorMessage: String?

    private var candidateTrips: [Itinerary] {
        ActiveTripResolver.activeOrUpcoming(Array(allTrips))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 4) {
                    Text(destination.name ?? "Destination")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppBrand.navy)
                    if let category = destination.category {
                        Text(category)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if let forecast {
                HStack(spacing: 16) {
                    stat(symbol: forecast.condition.symbolName, value: "\(Int(forecast.high.rounded()))°")
                    stat(symbol: "drop.fill", value: "\(forecast.rainProbability)% rain")
                    stat(symbol: "sun.max.fill", value: "UV \(Int(forecast.uvIndex.rounded()))")
                }
            } else {
                Text("Weather unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                addToTripButton
                viewDetailsLink
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationDestination(isPresented: $showPlanTrip) {
            PlanTripView(destination: destination)
        }
        .confirmationDialog("Add to which trip?", isPresented: $showTripPicker, titleVisibility: .visible) {
            ForEach(candidateTrips, id: \.objectID) { trip in
                Button(trip.title ?? "Untitled trip") { add(to: trip) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(
            "Couldn't add stop",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var addToTripButton: some View {
        Button(action: addToTripTapped) {
            HStack(spacing: 6) {
                Image(systemName: addedTripTitle != nil ? "checkmark.circle.fill" : "plus.circle.fill")
                Text(addedTripTitle != nil ? "Added" : "Add to Trip")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppBrand.navy.opacity(0.08), in: Capsule())
            .foregroundStyle(AppBrand.navy)
        }
        .buttonStyle(.plain)
        .disabled(addedTripTitle != nil)
    }

    private var viewDetailsLink: some View {
        NavigationLink(value: destination) {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                Text("View details")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppBrand.tealMid, in: Capsule())
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func addToTripTapped() {
        switch candidateTrips.count {
        case 0:
            showPlanTrip = true
        case 1:
            add(to: candidateTrips[0])
        default:
            showTripPicker = true
        }
    }

    private func add(to trip: Itinerary) {
        let repository = TripRepository(context: context)
        let stopCount = (trip.stops as? Set<ItineraryStop>)?.count ?? 0
        let date = trip.endDate.flatMap { Calendar.current.date(byAdding: .day, value: 1, to: $0) }
            ?? Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        do {
            try repository.addStop(to: trip, poi: POI(destination: destination), date: date, sortIndex: Int16(stopCount))
            trip.startDate = [trip.startDate, date].compactMap { $0 }.min()
            trip.endDate = [trip.endDate, date].compactMap { $0 }.max()
            try context.save()
            try repository.recomputeConflicts(for: trip)
            addedTripTitle = trip.title
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = "Couldn't add this stop. Try again."
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = destination.imageURL.flatMap(URL.init(string:)) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Color(.secondarySystemBackground)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 64, height: 64)
        }
    }

    private func stat(symbol: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(AppBrand.navy)
    }
}

#Preview {
    MapTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
