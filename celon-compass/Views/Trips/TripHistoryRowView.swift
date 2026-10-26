//
//  TripHistoryRowView.swift
//  celon-compass
//
//

import SwiftUI
import CoreData

struct TripHistoryRowView: View {
    let trip: Itinerary

    var body: some View {
        HStack(spacing: 14) {
            thumbnailStack

            VStack(alignment: .leading, spacing: 2) {
                Text(trip.title ?? "Untitled trip")
                    .font(.subheadline.weight(.semibold))
                Text("\(dateRangeText) · \(stopCountText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

    private var stops: [ItineraryStop] {
        ((trip.stops as? Set<ItineraryStop>) ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var thumbnailURLs: [URL] {
        Array(stops.compactMap { $0.destination?.imageURL.flatMap(URL.init(string:)) }.prefix(3))
    }

    @ViewBuilder
    private var thumbnailStack: some View {
        if thumbnailURLs.isEmpty {
            Image(systemName: "map.fill")
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(AppBrand.tealTop.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            ZStack {
                ForEach(Array(thumbnailURLs.enumerated()), id: \.offset) { index, url in
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: Rectangle().fill(Color(.tertiarySystemBackground))
                        }
                    }
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppBrand.card, lineWidth: 2))
                    .offset(x: CGFloat(index) * 10)
                }
            }
            .frame(width: 40 + CGFloat(max(thumbnailURLs.count - 1, 0)) * 10, height: 40, alignment: .leading)
        }
    }

    private var dateRangeText: String {
        guard let start = trip.startDate else { return "No dates" }
        guard let end = trip.endDate, !Calendar.current.isDate(end, inSameDayAs: start) else {
            return start.formatted(date: .abbreviated, time: .omitted)
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
    trip.title = "Cultural Triangle"
    trip.startDate = Calendar.current.date(byAdding: .day, value: -230, to: .now)
    trip.endDate = Calendar.current.date(byAdding: .day, value: -225, to: .now)

    return VStack(spacing: 0) {
        TripHistoryRowView(trip: trip)
    }
    .background(AppBrand.card)
    .padding()
}
