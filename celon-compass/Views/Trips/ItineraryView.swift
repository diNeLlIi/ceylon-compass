//
//  ItineraryView.swift
//  celon-compass
//
//

import Charts
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
    @State private var showRenameAlert = false
    @State private var renameDraft = ""
    @State private var showCompleteTripSheet = false

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

                if let notice = viewModel.doubleBookedNotice(from: Array(stops)) {
                    DoubleBookedNoticeView(
                        title: notice.title,
                        message: notice.message,
                        fixAction: { viewModel.resolveDoubleBooked(notice) }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                if let banner = viewModel.attentionBanner(from: Array(stops)) {
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

//                suitabilityChart
//                    .listRowInsets(EdgeInsets())
//                    .listRowBackground(Color.clear)
//                    .listRowSeparator(.hidden)
            }
            
            
            ForEach(daySections) { section in
                Section {
                    ForEach(section.stops) { stop in
                        HStack(alignment: .top, spacing: 10) {
                            timelineMarker(
                                index: globalIndex(of: stop),
                                isLast: isLastStopOverall(stop),
                                severity: conflictSeverity(for: stop)
                            )
                            VStack(alignment: .leading, spacing: 6) {
                                StopRow(
                                    title: stop.poiName ?? "Unknown",
                                    time: stop.date?.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)),
                                    note: stop.travelNotes,
                                    imageURL: stop.destination?.imageURL.flatMap(URL.init(string:)),
                                    forecast: viewModel.forecast(for: stop),
                                    forecastUnavailableLabel: weatherFallbackLabel(for: stop),
                                    detailedForecast: true,
                                    isGem: stop.poiSource == POI.Source.osm.rawValue,
                                    conflictSeverity: conflictSeverity(for: stop)
                                )
                                if let next = nextStop(after: stop) {
                                    travelCaptionRow(from: stop, to: next)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: Self.stopRowGap, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .onMove { source, destination in
                        viewModel.reorder(day: section, from: source, to: destination)
                    }
                    .onDelete { offsets in
                        for index in offsets { viewModel.deleteStop(section.stops[index]) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(0)
        .scrollContentBackground(.hidden)
        .background(AppBrand.canvas)
        .navigationTitle("Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
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

                    if trip.completedAt == nil {
                        Button {
                            showCompleteTripSheet = true
                        } label: {
                            Label("Complete Trip", systemImage: "checkmark.circle")
                        }
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
        .refreshable { await viewModel.loadForecasts(for: Array(stops)) }
        .onChange(of: stopsRevision) { _, _ in viewModel.clearDismissals() }
        .sheet(isPresented: $showCompleteTripSheet) {
            CompleteTripSheet(trip: trip)
        }
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
        .alert("Rename trip", isPresented: $showRenameAlert) {
            TextField("Trip name", text: $renameDraft)
            Button("Save") { renameTrip() }
            Button("Cancel", role: .cancel) {}
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

    // Changes on reorder, reschedule, add and delete — unlike stops.count, which a reorder
    // leaves untouched. Drives the "Keep" dismissal reset.
    private var stopsRevision: String {
        stops
            .map { "\($0.id?.uuidString ?? "")|\($0.date?.timeIntervalSince1970 ?? 0)|\($0.sortOrder)" }
            .joined(separator: ",")
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(trip.title ?? "Untitled trip")
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Button {
                    renameDraft = trip.title ?? ""
                    showRenameAlert = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rename trip")
                Spacer(minLength: 0)
            }

            Text(subtitleText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private var subtitleText: String {
        let countText = "\(stops.count) stop\(stops.count == 1 ? "" : "s")"
        guard let start = trip.startDate, let end = trip.endDate else { return countText }
        return "\(dateRangeText(start: start, end: end)) · \(countText)"
    }

    @ViewBuilder
    private var suitabilityChart: some View {
        let days = viewModel.daySuitabilityScores(from: Array(stops))
        if days.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Suitability by day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Chart(days) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Suitability", day.score)
                    )
                    .foregroundStyle(day.isIdeal ? Color.mint : Color(.tertiaryLabel))
                }
                .chartYScale(domain: 0...100)
                .frame(height: 120)
            }
            .padding(.horizontal)
            .padding(.top, 4)
        }
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

    private func nextStop(after stop: ItineraryStop) -> ItineraryStop? {
        guard let index = orderedStopIDs.firstIndex(of: stop.objectID), index + 1 < stops.count else { return nil }
        return stops[index + 1]
    }

    private func conflictSeverity(for stop: ItineraryStop) -> StopRow.ConflictSeverity {
        switch stop.conflictKind {
        case "stormRisk": return .severe
        case "travelTime", "doubleBooked": return .caution
        default: return .none
        }
    }

    // Only fires when there's nothing else to show
    private func weatherFallbackLabel(for stop: ItineraryStop) -> String? {
        guard viewModel.forecast(for: stop) == nil else { return nil }
        if stop.conflictKind == "stormRisk" { return "Storm risk" }
        if let date = stop.date, !ForecastHorizon.isAvailable(for: date) { return "Forecast not yet available" }
        return nil
    }

   
    private static let stopRowGap: CGFloat = 10

    private func timelineMarker(index: Int, isLast: Bool, severity: StopRow.ConflictSeverity) -> some View {
        VStack(spacing: 0) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(severity == .severe ? AppBrand.destructiveSolid : AppBrand.tealTop, in: Circle())
            if !isLast {
                Rectangle()
                    .fill(AppBrand.hairline)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 24)
        .padding(.top, 8)
        .padding(.bottom, isLast ? 0 : -Self.stopRowGap)
    }

    private func travelCaptionRow(from: ItineraryStop, to: ItineraryStop) -> some View {
        let estimate = routingService.estimate(
            from: Coordinate(latitude: from.poiLatitude, longitude: from.poiLongitude),
            to: Coordinate(latitude: to.poiLatitude, longitude: to.poiLongitude)
        )
        return Label(travelText(estimate: estimate), systemImage: "clock")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
    }

    private func travelText(estimate: RouteEstimate) -> String {
        let hours = Int(estimate.duration / 3600)
        let minutes = Int((estimate.duration.truncatingRemainder(dividingBy: 3600)) / 60)
        let durationText = hours > 0 ? "\(hours) h \(minutes) min" : "\(minutes) min"
        return "\(durationText) · \(Int(estimate.distanceKm.rounded())) km"
    }

    private var shareText: String {
        var lines = [trip.title ?? "Trip"]
        if let start = trip.startDate, let end = trip.endDate {
            lines.append(dateRangeText(start: start, end: end))
        }
        for stop in stops {
            let dateText = stop.date?.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) ?? ""
            lines.append("• \(stop.poiName ?? "Stop") — \(dateText)")
        }
        return lines.joined(separator: "\n")
    }

    private func moveActionTitle(for banner: ItineraryViewModel.Banner) -> String {
        let weekday = banner.suggestedDate.formatted(.dateTime.weekday(.abbreviated).day())
        let condition = banner.suggestedDateIsClear ? "clear" : "better odds"
        return "Move to \(weekday) · \(condition)"
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

    private func renameTrip() {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try TripRepository(context: context).renameTrip(trip, to: trimmed)
        } catch {
            viewModel.errorMessage = "Couldn't rename the trip. Try again."
        }
    }

    private func dateRangeText(start: Date, end: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(start, inSameDayAs: end) {
            return start.formatted(date: .abbreviated, time: .omitted)
        }
        let sameMonth = calendar.isDate(start, equalTo: end, toGranularity: .month)
            && calendar.isDate(start, equalTo: end, toGranularity: .year)
        if sameMonth {
            return "\(start.formatted(.dateTime.day()))–\(end.formatted(.dateTime.day())) \(end.formatted(.dateTime.month(.abbreviated).year()))"
        }
        return "\(start.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(.dateTime.day().month(.abbreviated).year()))"
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
    trip.endDate = Calendar.current.date(byAdding: .day, value: 4, to: .now)

    let stop1 = ItineraryStop(context: context)
    stop1.id = UUID()
    stop1.poiName = "Galle Fort"
    stop1.date = .now
    stop1.sortOrder = 0
    stop1.poiLatitude = 6.0300
    stop1.poiLongitude = 80.2170
    stop1.itinerary = trip

    let stop2 = ItineraryStop(context: context)
    stop2.id = UUID()
    stop2.poiName = "Mirissa"
    stop2.date = Calendar.current.date(byAdding: .day, value: 2, to: .now)
    stop2.sortOrder = 0
    stop2.hasConflict = true
    stop2.conflictKind = "doubleBooked"
    stop2.poiLatitude = 5.9483
    stop2.poiLongitude = 80.4589
    stop2.itinerary = trip

    let stop3 = ItineraryStop(context: context)
    stop3.id = UUID()
    stop3.poiName = "Ella"
    stop3.date = Calendar.current.date(byAdding: .day, value: 2, to: .now)
    stop3.sortOrder = 1
    stop3.hasConflict = true
    stop3.conflictKind = "stormRisk"
    stop3.poiLatitude = 6.8667
    stop3.poiLongitude = 81.0466
    stop3.itinerary = trip

    let stop4 = ItineraryStop(context: context)
    stop4.id = UUID()
    stop4.poiName = "Yala"
    stop4.date = Calendar.current.date(byAdding: .day, value: 4, to: .now)
    stop4.sortOrder = 0
    stop4.poiLatitude = 6.2815
    stop4.poiLongitude = 81.4126
    stop4.itinerary = trip

    try? context.save()

    return NavigationStack {
        ItineraryView(trip: trip)
    }
    .environment(\.managedObjectContext, context)
}
