//
//  DestinationDetailView.swift
//  celon-compass
//
//

import SwiftUI
import CoreData

struct DestinationDetailView: View {
    @StateObject private var viewModel: DestinationDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPlanTrip = false

    init(destination: Destination, forecasts: [DayForecast], favouritesStore: FavouritesStore = .shared) {
        _viewModel = StateObject(wrappedValue: DestinationDetailViewModel(
            destination: destination,
            forecasts: forecasts,
            favouritesStore: favouritesStore
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                bestWindowBanner
                forecastStrip
                if viewModel.forecasts.count > 1 {
                    ForecastChartsView(forecasts: viewModel.forecasts)
                }
                aboutSection
            }
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .background(AppBrand.canvas)
        .safeAreaInset(edge: .bottom) { planTripButton }
        .navigationDestination(isPresented: $showPlanTrip) {
            PlanTripView(destination: viewModel.destination)
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .frame(height: 320)
                .overlay {
                    AsyncImage(url: viewModel.destination.imageURL.flatMap(URL.init(string:))) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
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

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if let category = viewModel.destination.category {
                        Text(category.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(AppBrand.navy)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppBrand.amber, in: Capsule())
                    }
                    if let province = viewModel.destination.province {
                        Text(province)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Text(viewModel.destination.name ?? "Unknown")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
            }
            .padding(16)
        }
        .overlay(alignment: .top) {
            HStack {
                circleButton(systemImage: "chevron.left") { dismiss() }
                Spacer()
                circleButton(
                    systemImage: viewModel.isFavourite ? "heart.fill" : "heart",
                    tint: viewModel.isFavourite ? AppBrand.amber : .white
                ) { viewModel.toggleFavourite() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 54)
        }
    }

    private func circleButton(systemImage: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var bestWindowBanner: some View {
        if let bestWindow = viewModel.bestWindow, let first = bestWindow.days.first, let last = bestWindow.days.last {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                Text(bannerText(first: first, last: last, isAllClear: bestWindow.isAllClear))
                    .font(.subheadline.weight(.medium))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppBrand.tealTop.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private func bannerText(first: Date, last: Date, isAllClear: Bool) -> String {
        let formatter = Date.FormatStyle().month(.abbreviated).day()
        let range = first == last
            ? first.formatted(formatter)
            : "\(first.formatted(formatter))–\(last.formatted(.dateTime.day()))"
        let condition = isAllClear ? "Clear" : "Low rain risk"
        return "Best days this week · \(range) · \(condition)"
    }

    @ViewBuilder
    private var forecastStrip: some View {
        if !viewModel.forecasts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("7-Day Forecast")
                    .font(.headline)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(viewModel.forecasts.enumerated()), id: \.element.id) { index, forecast in
                            DayForecastCard(forecast: forecast, isToday: index == 0)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        if let description = viewModel.destination.descriptionText, !description.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("About \(viewModel.destination.name ?? "")")
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
    }

    private var planTripButton: some View {
        Button {
            showPlanTrip = true
        } label: {
            HStack {
                Text("Plan a Trip Here")
                    .font(.headline)
                Image(systemName: "arrow.right")
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppBrand.tealTop, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let destination = Destination(context: context)
    destination.id = UUID()
    destination.name = "Ella"
    destination.category = "Mountain"
    destination.province = "Uva Province"
    destination.descriptionText = "A hill-country town wrapped in tea estates and cloud forest."
    destination.imageURL = "https://upload.wikimedia.org/wikipedia/commons/c/c7/Sigiriya.jpg"
    let favouritesStore = FavouritesStore(context: context)

    let forecasts = (0..<7).map { offset in
        DayForecast(
            date: Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now,
            high: 24 + Double(offset % 3),
            low: 16 + Double(offset % 3),
            rainProbability: [20, 10, 45, 80, 35, 10, 15][offset],
            uvIndex: 6,
            condition: [.cloudy, .clear, .cloudy, .storm, .cloudy, .clear, .clear][offset]
        )
    }

    return NavigationStack {
        DestinationDetailView(destination: destination, forecasts: forecasts, favouritesStore: favouritesStore)
    }
}
