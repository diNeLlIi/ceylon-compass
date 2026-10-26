//
//  ItineraryView.swift
//  celon-compass
//
//

import SwiftUI
import CoreData

struct ItineraryView: View {
    let trip: Itinerary
    @StateObject private var viewModel: ItineraryViewModel
    @FetchRequest private var stops: FetchedResults<ItineraryStop>
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.editMode) private var editMode
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?

    init(trip: Itinerary) {
        self.trip = trip
        let context = trip.managedObjectContext ?? PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: ItineraryViewModel(trip: trip, context: context))
        _stops = FetchRequest(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \ItineraryStop.date, ascending: true),
                NSSortDescriptor(keyPath: \ItineraryStop.sortOrder, ascending: true)
            ],
            predicate: NSPredicate(format: "itinerary == %@", trip)
        )
    }

    private var daySections: [ItineraryViewModel.DaySection] {
        viewModel.daySections(from: Array(stops))
    }

    var body: some View {
        List {
            Section {
                headerCard
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                if let banner = viewModel.banner(from: Array(stops)) {
                    AttentionBanner(
                        title: banner.title,
                        message: banner.message,
                        primaryActionTitle: moveActionTitle(for: banner),
                        primaryAction: { viewModel.resolveConflict(banner) },
                        secondaryActionTitle: "Keep",
                        secondaryAction: { viewModel.keep(banner) }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            ForEach(Array(daySections.enumerated()), id: \.element.id) { dayIndex, section in
                Section {
                    ForEach(section.stops) { stop in
                        HStack(alignment: .top, spacing: 10) {
                            timelineMarker(
                                index: globalIndex(of: stop),
                                isLast: isLastStopOverall(stop),
                                hasConflict: stop.hasConflict
                            )
                            StopRow(
                                title: stop.poiName ?? "Unknown",
                                time: stop.date?.formatted(date: .omitted, time: .shortened),
                                note: stop.travelNotes,
                                imageURL: stop.destination?.imageURL.flatMap(URL.init(string:)),
                                forecast: viewModel.forecast(for: stop),
                                isGem: stop.poiSource == POI.Source.osm.rawValue,
                                hasConflict: stop.hasConflict,
                                accessory: .dragHandle
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .onMove { source, destination in
                        viewModel.reorder(day: section, from: source, to: destination)
                    }
                    .onDelete { offsets in
                        for index in offsets { viewModel.deleteStop(section.stops[index]) }
                    }

                    if dayIndex < daySections.count - 1,
                       let lastStop = section.stops.last,
                       let nextStop = daySections[dayIndex + 1].stops.first {
                        travelCaptionRow(from: lastStop, to: nextStop)
                            .listRowInsets(EdgeInsets(top: 0, leading: 48, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    dayHeader(section)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppBrand.canvas)
        .navigationTitle(trip.title ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        withAnimation {
                            editMode?.wrappedValue = editMode?.wrappedValue == .active ? .inactive : .active
                        }
                    } label: {
                        Label(
                            editMode?.wrappedValue == .active ? "Done" : "Edit Stops",
                            systemImage: editMode?.wrappedValue == .active ? "checkmark" : "pencil"
                        )
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Trip", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task(id: stops.count) { await viewModel.loadForecasts(for: Array(stops)) }
        .confirmationDialog(
            "Delete this trip?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Trip", role: .destructive) { deleteTrip() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(trip.title ?? "Untitled trip")\" and all its stops will be permanently removed.")
        }
        .alert(
            "Trip not deleted",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(trip.title ?? "Untitled trip")
                .font(.largeTitle.bold())

            if let start = trip.startDate, let end = trip.endDate {
                Text(dateRangeText(start: start, end: end))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                statBlock(value: "\(daySections.count)", label: "DAYS")
                statBlock(value: "\(stops.count)", label: "STOPS")
                statBlock(value: "\(Int(totalDrivingKm.rounded())) km", label: "DRIVING")
                statBlock(value: clearDaysLabel, label: "CLEAR")
            }
            .padding(.top, 4)
        }
        .padding()
        .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func dayHeader(_ section: ItineraryViewModel.DaySection) -> some View {
        HStack {
            Text(section.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            if let forecast = section.stops.first.flatMap(viewModel.forecast(for:)) {
                WeatherBadgeView(forecast: forecast, style: .onSurface)
            } else if section.stops.contains(where: \.hasConflict) {
                Text("Storm risk")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppBrand.destructive)
            }
        }
        .textCase(nil)
    }

    private let routingService: RoutingServicing = HaversineRoutingService()

    private var orderedStopIDs: [NSManagedObjectID] {
        Array(stops).map(\.objectID)
    }

    private func globalIndex(of stop: ItineraryStop) -> Int {
        orderedStopIDs.firstIndex(of: stop.objectID) ?? 0
    }

    private func isLastStopOverall(_ stop: ItineraryStop) -> Bool {
        orderedStopIDs.last == stop.objectID
    }

    private func timelineMarker(index: Int, isLast: Bool, hasConflict: Bool) -> some View {
        VStack(spacing: 0) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(hasConflict ? AppBrand.destructive : AppBrand.tealTop, in: Circle())
            if !isLast {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
            }
        }
        .padding(.top, 6)
    }

    private func travelCaptionRow(from: ItineraryStop, to: ItineraryStop) -> some View {
        let estimate = routingService.estimate(
            from: Coordinate(latitude: from.poiLatitude, longitude: from.poiLongitude),
            to: Coordinate(latitude: to.poiLatitude, longitude: to.poiLongitude)
        )
        return Label(travelText(estimate: estimate, destinationName: to.poiName ?? "next stop"), systemImage: "arrow.turn.down.right")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private func travelText(estimate: RouteEstimate, destinationName: String) -> String {
        let hours = Int(estimate.duration / 3600)
        let minutes = Int((estimate.duration.truncatingRemainder(dividingBy: 3600)) / 60)
        let durationText = hours > 0 ? "\(hours) h \(minutes) min" : "\(minutes) min"
        return "\(durationText) · \(Int(estimate.distanceKm.rounded())) km to \(destinationName)"
    }

    private var totalDrivingKm: Double {
        var points = [Coordinate(latitude: trip.originLat, longitude: trip.originLon)]
        points.append(contentsOf: stops.map { Coordinate(latitude: $0.poiLatitude, longitude: $0.poiLongitude) })
        guard points.count >= 2 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0.0) { $0 + Haversine.distanceKm(from: $1.0, to: $1.1) }
    }

    private var clearDaysLabel: String {
        var clear = 0
        var total = 0
        for section in daySections {
            guard let stop = section.stops.first, let forecast = viewModel.forecast(for: stop) else { continue }
            total += 1
            if forecast.condition == .clear { clear += 1 }
        }
        return total > 0 ? "\(clear) of \(total)" : "–"
    }

    private func moveActionTitle(for banner: ItineraryViewModel.Banner) -> String {
        let weekday = banner.suggestedDate.formatted(.dateTime.weekday(.abbreviated).day())
        let condition = banner.suggestedDateIsClear ? "clear" : "better odds"
        return "Move \(banner.stopToMove.poiName ?? "stop") to \(weekday) · \(condition)"
    }

    private func deleteTrip() {
        Task {
            do {
                try await TripRepository(context: context).deleteTrip(trip)
                dismiss()
            } catch {
                deleteError = DestructiveActionGuard.userMessage(for: error, noun: "the trip")
            }
        }
    }

    private func dateRangeText(start: Date, end: Date) -> String {
        if Calendar.current.isDate(start, inSameDayAs: end) {
            return start.formatted(date: .abbreviated, time: .omitted)
        }
        return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day().year()))"
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let trip = Itinerary(context: context)
    trip.id = UUID()
    trip.title = "South Coast Run"
    trip.originName = DefaultOrigin.name
    trip.originLat = DefaultOrigin.coordinate.latitude
    trip.originLon = DefaultOrigin.coordinate.longitude
    trip.startDate = .now
    trip.endDate = Calendar.current.date(byAdding: .day, value: 2, to: .now)

    let stop1 = ItineraryStop(context: context)
    stop1.id = UUID()
    stop1.poiName = "Galle Fort"
    stop1.date = .now
    stop1.sortOrder = 0
    stop1.itinerary = trip

    let stop2 = ItineraryStop(context: context)
    stop2.id = UUID()
    stop2.poiName = "Mirissa"
    stop2.date = Calendar.current.date(byAdding: .day, value: 2, to: .now)
    stop2.sortOrder = 0
    stop2.hasConflict = true
    stop2.itinerary = trip

    let stop3 = ItineraryStop(context: context)
    stop3.id = UUID()
    stop3.poiName = "Ella"
    stop3.date = Calendar.current.date(byAdding: .day, value: 2, to: .now)
    stop3.sortOrder = 1
    stop3.hasConflict = true
    stop3.itinerary = trip

    try? context.save()

    return NavigationStack {
        ItineraryView(trip: trip)
    }
    .environment(\.managedObjectContext, context)
}
