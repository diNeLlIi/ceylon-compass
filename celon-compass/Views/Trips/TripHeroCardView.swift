//
//  TripHeroCardView.swift
//  celon-compass
//
//

import SwiftUI
import CoreData

struct TripHeroCardView: View {
    struct DayEntry: Identifiable {
        let date: Date
        let stop: ItineraryStop?
        var id: Date { date }
    }

    let trip: Itinerary
    @ObservedObject var viewModel: MyTripsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            hero
            if !dayEntries.isEmpty {
                HStack(spacing: 6) {
                    ForEach(dayEntries) { entry in
                        dayChip(date: entry.date, stop: entry.stop)
                    }
                }
            }
        }
        .padding(10)
        .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    private var hero: some View {
        Color.clear
            .frame(height: 140)
            .overlay {
                if let heroImageURL {
                    AsyncImage(url: heroImageURL) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: heroFallback
                        }
                    }
                } else {
                    heroFallback
                }
            }
            .clipped()
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .topTrailing) {
                if let badgeText = daysUntilText {
                    Text(badgeText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppBrand.heading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppBrand.amber, in: Capsule())
                        .padding(10)
                }
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.title ?? "Untitled trip")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(dateRangeText) · \(stopCountText)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var heroFallback: some View {
        LinearGradient(colors: [AppBrand.tealTop, AppBrand.navy], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func dayChip(date: Date, stop: ItineraryStop?) -> some View {
        let forecast = stop.flatMap(viewModel.forecast(for:))
        let hasConflict = stop?.hasConflict ?? false
        let isForecastPending = stop != nil && forecast == nil && !ForecastHorizon.isAvailable(for: date)
        let chip = VStack(spacing: 2) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.system(size: 10, weight: .semibold))
            Image(systemName: isForecastPending ? "clock" : (forecast?.condition.symbolName ?? "minus"))
                .font(.caption)
            Text(forecast.map { "\(Int($0.high.rounded()))°" } ?? (isForecastPending ? "soon" : "–"))
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(hasConflict ? AppBrand.destructive : (stop == nil ? Color.secondary : Color.primary))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(chipBackground(condition: forecast?.condition, hasConflict: hasConflict), in: RoundedRectangle(cornerRadius: 9))

        return Group {
            if isForecastPending {
                chip.accessibilityLabel("Forecast not yet available")
            } else {
                chip
            }
        }
    }

    private func chipBackground(condition: WeatherCondition?, hasConflict: Bool) -> Color {
        if hasConflict { return AppBrand.destructiveTint }
        switch condition {
        case .clear: return Color.green.opacity(0.14)
        case .cloudy: return Color.orange.opacity(0.12)
        case .rain: return Color.blue.opacity(0.12)
        case .storm: return AppBrand.destructiveTint
        case nil: return Color(.secondarySystemBackground)
        }
    }

    private var stops: [ItineraryStop] {
        ((trip.stops as? Set<ItineraryStop>) ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    
    private var dayEntries: [DayEntry] {
        guard let start = trip.startDate, let end = trip.endDate else { return [] }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay else { return [] }

        var firstStopByDay: [DateComponents: ItineraryStop] = [:]
        for stop in stops {
            guard let date = stop.date else { continue }
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            if firstStopByDay[components] == nil {
                firstStopByDay[components] = stop
            }
        }

        var result: [DayEntry] = []
        var cursor = startDay
        while cursor <= endDay {
            let components = calendar.dateComponents([.year, .month, .day], from: cursor)
            result.append(DayEntry(date: cursor, stop: firstStopByDay[components]))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? endDay.addingTimeInterval(1)
        }
        return result
    }

    private var heroImageURL: URL? {
        stops.first?.destination?.imageURL.flatMap(URL.init(string:))
    }

    private var daysUntilText: String? {
        guard let start = trip.startDate else { return nil }
        let today = Calendar.current.startOfDay(for: .now)
        let startDay = Calendar.current.startOfDay(for: start)
        let days = Calendar.current.dateComponents([.day], from: today, to: startDay).day ?? 0
        if days > 0 { return "IN \(days) DAY\(days == 1 ? "" : "S")" }
        if let end = trip.endDate, Calendar.current.startOfDay(for: end) >= today { return "ACTIVE" }
        return "TODAY"
    }

    private var dateRangeText: String {
        guard let start = trip.startDate else { return "No dates yet" }
        guard let end = trip.endDate, !Calendar.current.isDate(end, inSameDayAs: start) else {
            return start.formatted(.dateTime.month(.abbreviated).day())
        }
        return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    private var stopCountText: String {
        let count = stops.count
        return count == 1 ? "1 stop" : "\(count) stops"
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let trip = Itinerary(context: context)
    trip.id = UUID()
    trip.title = "South Coast Run"
    trip.startDate = Calendar.current.date(byAdding: .day, value: 6, to: .now)
    trip.endDate = Calendar.current.date(byAdding: .day, value: 10, to: .now)

    return TripHeroCardView(trip: trip, viewModel: MyTripsViewModel())
        .padding()
        .background(AppBrand.canvas)
}
