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

    @State private var position: MapCameraPosition = .region(Self.sriLanka)
    @State private var mapStyle: MapStyleChoice = .standard
    @State private var selected: Destination?
    @State private var forecasts: [UUID: [DayForecast]] = [:]
    @State private var isLoadingWeather = false

    private let weatherService: WeatherServicing = WeatherService()

    private static let sriLanka = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 7.8731, longitude: 80.7718),
        span: MKCoordinateSpan(latitudeDelta: 3.4, longitudeDelta: 3.2)
    )

    var body: some View {
        NavigationStack {
            Map(position: $position, selection: $selected) {
                ForEach(Array(destinations), id: \.self) { destination in
                    Annotation(
                        destination.name ?? "Destination",
                        coordinate: CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
                    ) {
                        WeatherPin(forecast: destinationForecast(destination))
                            .onTapGesture { selected = destination }
                    }
                    .tag(destination)
                }
            }
            .mapStyle(mapStyle.swiftUIStyle)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    styleToggle
                }
            }
            .task { await loadWeatherIfNeeded() }
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

private struct DestinationQuickSheet: View {
    let destination: Destination
    let forecast: DayForecast?

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
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
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
