//
//  MapPinSheets.swift
//  celon-compass
//
//  The map's quick sheet, routed on MapPin.kind.

import CoreData
import SwiftUI

struct MapPinSheet: View {
    let pin: MapPin

    var body: some View {
        switch pin.kind {
        case let .tripStop(order, date):
            TripStopSheet(pin: pin, order: order, date: date)
        case let .visited(rating, visitDate):
            VisitedSheet(pin: pin, rating: rating, visitDate: visitDate)
        case .searchResult:
            if let destination = pin.destination {
                DestinationQuickSheet(destination: destination, forecast: pin.forecast)
            }
        }
    }
}


//Trip stop

struct TripStopSheet: View {
    let pin: MapPin
    let order: Int
    let date: Date?

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showRemoveConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text("\(order)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(AppBrand.tealMid, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(pin.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppBrand.heading)
                    if let date {
                        Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if let stop = pin.stop, stop.hasConflict {
                Label(conflictMessage(stop.conflictKind), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppBrand.destructive)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppBrand.destructiveTint, in: RoundedRectangle(cornerRadius: 10))
            }

            if let forecast = pin.forecast {
                ForecastStatRow(forecast: forecast)
            } else if pin.destination == nil {
                Text("Saved from OpenStreetMap. No forecast for this spot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Weather unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
//                Button(role: .destructive) {
//                    showRemoveConfirmation = true
//                }
//                 label: {
//                     Label("Remove", systemImage: "minus.circle.fill")
//                         .font(.subheadline.weight(.semibold))
//                         .frame(maxWidth: .infinity)
//                         .padding(.vertical, 12)
//                         .background(AppBrand.destructiveTint, in: Capsule())
//                         .foregroundStyle(AppBrand.destructive)
//                 }
//                 .buttonStyle(.plain)

                if let trip = pin.stop?.itinerary {
                    NavigationLink(value: trip) {
                        Label("View trip", systemImage: "arrow.right.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppBrand.tealMid, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog(
            "Remove \(pin.name) from this trip?",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove stop", role: .destructive) { remove() }
            Button("Cancel", role: .cancel) {}
        }
        .alert(
            "Couldn't remove stop",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func remove() {
        guard let stop = pin.stop else { return }
        do {
            try TripRepository(context: context).deleteStop(stop)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorMessage = "Try again."
        }
    }

    private func conflictMessage(_ kind: String?) -> String {
        switch kind {
        case "stormRisk": "Storms forecast for this day"
        case "travelTime": "Tight travel time from the previous stop"
        case "doubleBooked": "Another stop is booked the same day"
        default: "This stop has a conflict"
        }
    }
}


//Visited

struct VisitedSheet: View {
    let pin: MapPin
    let rating: Int16
    let visitDate: Date?

    @Environment(\.managedObjectContext) private var context
    @State private var draftRating: Int16 = 0
    @State private var note: String = ""
    @State private var isEditingNote = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: VisitedGhostPin.symbol(for: pin.destination?.category))
                    .font(.title3)
                    .foregroundStyle(AppBrand.heading.opacity(0.6))
                    .frame(width: 40, height: 40)
                    .background(AppBrand.cardHighlight, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(pin.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppBrand.heading)
                        Label("Visited", systemImage: "checkmark.circle.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppBrand.success)
                            .labelStyle(.titleAndIcon)
                    }
                    if let visitDate {
                        Text(visitDate.formatted(.dateTime.day().month(.wide).year()))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            draftRating = Int16(star)
                            persist()
                        } label: {
                            Image(systemName: star <= Int(draftRating) ? "star.fill" : "star")
                                .font(.subheadline)
                                .foregroundStyle(AppBrand.amber)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Rate \(star) of 5")
                    }
                }

                if isEditingNote {
                    TextField("Add a note", text: $note, axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { persist(); isEditingNote = false }
                } else {
                    Button {
                        isEditingNote = true
                    } label: {
                        Text(note.isEmpty ? "Add a note" : note)
                            .font(.subheadline)
                            .italic(!note.isEmpty)
                            .foregroundStyle(note.isEmpty ? .secondary : AppBrand.heading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppBrand.cardHighlight, in: RoundedRectangle(cornerRadius: 12))

            if let forecast = pin.forecast {
                ForecastStatRow(forecast: forecast)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            draftRating = rating
            note = pin.visit?.note?.text ?? ""
        }
    }

    private func persist() {
        guard let visit = pin.visit else { return }
        try? VisitLogger(context: context).update(
            visit,
            rating: draftRating,
            note: note.isEmpty ? nil : note
        )
        UISelectionFeedbackGenerator().selectionChanged()
    }
}



//Search result

// Shared by the catalog sheet and the gem sheet. Takes a POI rather than a Destination
// so an OpenStreetMap gem, which has no catalog row behind it, can be added the same way.
struct AddStopToTripControl: View {
    let poi: POI

    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Itinerary.startDate, ascending: true)]
    )
    private var allTrips: FetchedResults<Itinerary>

    @State private var showTripPicker = false
    @State private var addedTripTitle: String?
    @State private var errorMessage: String?

    private var candidateTrips: [Itinerary] {
        ActiveTripResolver.activeOrUpcoming(Array(allTrips))
    }

    var body: some View {
        Group {
            // Starting a new trip belongs to Explore; the map only adds to trips that exist
            if candidateTrips.isEmpty {
                Text("No active trip yet. Start one from Explore, then add stops from here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                button
            }
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

    private var button: some View {
        Button {
            if candidateTrips.count == 1 {
                add(to: candidateTrips[0])
            } else {
                showTripPicker = true
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: addedTripTitle != nil ? "checkmark.circle.fill" : "plus.circle.fill")
                Text(addedTripTitle != nil ? "Added" : "Add to Trip")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppBrand.accentTint, in: Capsule())
            .foregroundStyle(AppBrand.accentStrong)
        }
        .buttonStyle(.plain)
        .disabled(addedTripTitle != nil)
    }

    private func add(to trip: Itinerary) {
        let repository = TripRepository(context: context)
        let stopCount = (trip.stops as? Set<ItineraryStop>)?.count ?? 0
        let date = trip.endDate.flatMap { Calendar.current.date(byAdding: .day, value: 1, to: $0) }
            ?? Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        do {
            try repository.addStop(to: trip, poi: poi, date: date, sortIndex: Int16(stopCount))
            trip.startDate = [trip.startDate, date].compactMap { $0 }.min()
            trip.endDate = [trip.endDate, date].compactMap { $0 }.max()
            try context.save()
            addedTripTitle = trip.title
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = "Couldn't add this stop. Try again."
        }
    }
}

// A gem has no catalog row, so there is no image and no forecast to show — only the
// name, what OpenStreetMap called it, and the same Add to Trip action.
struct GemQuickSheet: View {
    let gem: POI

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppBrand.amberTint)
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppBrand.amber)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(gem.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppBrand.heading)
                    Text(gem.category ?? "Point of interest")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text("Community-mapped spot. No forecast for this location.")
                .font(.caption)
                .foregroundStyle(.secondary)

            AddStopToTripControl(poi: gem)

            Text("Location via OpenStreetMap contributors")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DestinationQuickSheet: View {
    let destination: Destination
    let forecast: DayForecast?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 4) {
                    Text(destination.name ?? "Destination")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppBrand.heading)
                    if let category = destination.category {
                        Text(category)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if let forecast {
                ForecastStatRow(forecast: forecast)
            } else {
                Text("Weather unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            AddStopToTripControl(poi: POI(destination: destination))
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
                    AppBrand.cardHighlight
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppBrand.cardHighlight)
                .frame(width: 64, height: 64)
        }
    }
}


//Shared

struct ForecastStatRow: View {
    let forecast: DayForecast

    var body: some View {
        HStack(spacing: 16) {
            stat(symbol: forecast.condition.symbolName, value: "\(Int(forecast.high.rounded()))°")
            stat(symbol: "drop.fill", value: "\(forecast.rainProbability)% rain")
            stat(symbol: "sun.max.fill", value: "UV \(Int(forecast.uvIndex.rounded()))")
        }
    }

    private func stat(symbol: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(AppBrand.heading)
    }
}
