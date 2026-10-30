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
                            .foregroundStyle(AppBrand.heading)
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
            .background(AppBrand.accentTint, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private func bannerText(first: Date, last: Date, isAllClear: Bool) -> String {
        let calendar = Calendar.current
        let range = calendar.isDate(first, inSameDayAs: last)
            ? first.formatted(.dateTime.day().month(.abbreviated))
            : "\(first.formatted(.dateTime.day()))–\(last.formatted(.dateTime.day().month(.abbreviated)))"
        let condition = isAllClear ? "Clear" : "Low rain risk"
        return "Best days \(scopeLabel(for: first)) · \(range) · \(condition)"
    }

    // The forecast now runs 14 days, so the window can land outside this week.
    private func scopeLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let target = calendar.dateInterval(of: .weekOfYear, for: date)?.start,
              let offset = calendar.dateComponents([.weekOfYear], from: thisWeek, to: target).weekOfYear
        else { return "ahead" }

        switch offset {
        case 0: return "this week"
        case 1: return "next week"
        default: return "ahead"
        }
    }

    @ViewBuilder
    private var forecastStrip: some View {
        if !viewModel.forecasts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Forecast")
                        .font(.headline)
                    Spacer()
//                    Text("\(viewModel.forecasts.count) days")
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                    Text(viewModel.forecastSpan)
//                        .font(.caption.weight(.medium))
//                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.forecasts) { forecast in
                            DayForecastCard(
                                forecast: forecast,
                                isToday: Calendar.current.isDateInToday(forecast.date),
                                isBestWindow: viewModel.isInBestWindow(forecast)
                            )
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal)
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    
//    private func weekSection(_ week: ForecastWeek) -> some View {
//        VStack(alignment: .leading, spacing: 10) {
//            weekHeader(week)
//
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 10) {
//                    ForEach(week.days) { forecast in
//                        DayForecastCard(
//                            forecast: forecast,
//                            isToday: Calendar.current.isDateInToday(forecast.date),
//                            isBestWindow: viewModel.isInBestWindow(forecast)
//                        )
//                    }
//                }
//                .padding(.horizontal)
//            }
//        }
//    }
//
//    private func weekHeader(_ week: ForecastWeek) -> some View {
//        HStack(alignment: .center, spacing: 10) {
//            // Fixed height so every section's indicator is identical, whether
//            // or not the title row carries a badge.
//            Capsule()
//                .fill(week.containsBestWindow ? AppBrand.tealTop : Color(.separator))
//                .frame(width: 3, height: 38)
//
//            VStack(alignment: .leading, spacing: 3) {
//                HStack(spacing: 8) {
//                    Text(week.title)
//                        .font(.subheadline.weight(.bold))
//                        .foregroundStyle(AppBrand.heading)
//
//                    if week.containsBestWindow {
//                        Text(week.bestDayBadge)
//                            .font(.system(size: 9, weight: .bold))
//                            .tracking(0.5)
//                            .foregroundStyle(AppBrand.tealMid)
//                            .padding(.horizontal, 6)
//                            .padding(.vertical, 2)
//                            .background(AppBrand.tealTop.opacity(0.15), in: Capsule())
//                    }
//
//                    Spacer(minLength: 8)
//
//                    Text(week.dateRange)
//                        .font(.caption.weight(.medium))
//                        .foregroundStyle(.secondary)
//                        .layoutPriority(1)
//                }
//
//                HStack(spacing: 5) {
//                    Image(systemName: week.dominantCondition.symbolName)
//                        .font(.caption2)
//                        .symbolRenderingMode(.hierarchical)
//                    Text(week.dominantCondition.label)
//                        .font(.caption)
//                    Text("·")
//                    Text(week.tempRange)
//                        .font(.caption)
//                    Text("·")
//                    Image(systemName: "drop.fill")
//                        .font(.system(size: 9))
//                    Text("\(week.avgRain)%")
//                        .font(.caption)
//                }
//                .foregroundStyle(.secondary)
//            }
//        }
//        .padding(.horizontal)
//        .accessibilityElement(children: .combine)
//        .accessibilityLabel(
//            "\(week.title), \(week.dateRange), \(week.accessibilitySummary)"
//                + (week.containsBestWindow
//                    ? ", \(week.bestDayCount) recommended \(week.bestDayCount == 1 ? "day" : "days")"
//                    : "")
//        )
//    }

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

    let rain = [20, 10, 45, 80, 35, 10, 15, 25, 60, 70, 15, 10, 30, 40]
    let conditions: [WeatherCondition] = [
        .cloudy, .clear, .cloudy, .storm, .cloudy, .clear, .clear,
        .cloudy, .rain, .storm, .clear, .clear, .cloudy, .rain
    ]
    let forecasts = (0..<14).map { offset in
        DayForecast(
            date: Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now,
            high: 24 + Double(offset % 3),
            low: 16 + Double(offset % 3),
            rainProbability: rain[offset],
            uvIndex: 6,
            condition: conditions[offset]
        )
    }

    return NavigationStack {
        DestinationDetailView(destination: destination, forecasts: forecasts, favouritesStore: favouritesStore)
    }
}
