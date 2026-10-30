//
//  TripListView.swift
//  celon-compass
//
//  My Trips: two distinct card views
//

import SwiftUI
import CoreData

struct TripListView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(TabRouter.self) private var router
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Itinerary.startDate, ascending: true)],
        animation: .default
    ) private var trips: FetchedResults<Itinerary>
    @StateObject private var viewModel = MyTripsViewModel()

    @State private var tripPendingDelete: Itinerary?
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var path = NavigationPath()
    @State private var openCardID: NSManagedObjectID?

    // Scoped to stops already on one of the user's own trips, active or past not the
    // full catalog. My Trips searches what you've planned, not what you could plan.
    private var matchingStops: [ItineraryStop] {
        guard !searchText.isEmpty else { return [] }
        let allStops = trips.flatMap { ($0.stops as? Set<ItineraryStop>) ?? [] }
        return allStops
            .filter { ($0.poiName ?? "").localizedCaseInsensitiveContains(searchText) }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    // Past trips
    private var activeUpcomingTrips: [Itinerary] {
        trips.filter { trip in
            guard let endDate = trip.endDate else { return true }
            return endDate >= Calendar.current.startOfDay(for: .now)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !searchText.isEmpty {
                    searchResults
                } else if activeUpcomingTrips.isEmpty {
                    emptyState
                } else {
                    tripList
                }
            }
            .background(AppBrand.canvas)
        
            .safeAreaInset(edge: .top) {
                DestinationSearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .background(AppBrand.canvas)
            }
            .navigationTitle("My Trips")
            .navigationBarTitleDisplayMode(.inline)
            .brandToolbar()
            .navigationDestination(for: Itinerary.self) { trip in
                ItineraryView(trip: trip)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        router.selection = .explore
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Plan a new trip")
                    .accessibilityIdentifier("trips.add")
                }
            }
            .task(id: trips.count) {
                await viewModel.loadForecasts(for: Array(trips))
            }
            .confirmationDialog(
                "Delete this trip?",
                isPresented: Binding(
                    get: { tripPendingDelete != nil },
                    set: { if !$0 { tripPendingDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: tripPendingDelete
            ) { trip in
                Button("Delete Trip", role: .destructive) { delete(trip) }
                Button("Cancel", role: .cancel) {}
            } message: { trip in
                Text("“\(trip.title ?? "Untitled trip")” and all its stops will be removed. You'll be asked to verify it's you.")
            }
            .alert(
                "Trip not deleted",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if matchingStops.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(matchingStops, id: \.objectID) { stop in
                        if let trip = stop.itinerary {
                            NavigationLink(value: trip) {
                                StopRow(
                                    title: stop.poiName ?? "Stop",
                                    subtitle: stopSubtitle(stop, trip: trip),
                                    imageURL: stop.destination?.imageURL.flatMap(URL.init(string:))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
    }

    private func stopSubtitle(_ stop: ItineraryStop, trip: Itinerary) -> String {
        var parts = [trip.title ?? "Untitled trip"]
        if let date = stop.date {
            parts.append(date.formatted(.dateTime.day().month(.abbreviated)))
        }
        return parts.joined(separator: " · ")
    }

    private var tripList: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(activeUpcomingTrips) { trip in
                    SwipeActionsCard(
                        id: trip.objectID,
                        openID: $openCardID,
                        cornerRadius: 20,
                        onEdit: { path.append(trip) },
                        onDelete: { tripPendingDelete = trip }
                    ) {
                        NavigationLink(value: trip) {
                            TripHeroCardView(trip: trip, viewModel: viewModel)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                tripPendingDelete = trip
                            } label: {
                                Label("Delete Trip", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "briefcase")
                    .font(.system(size: 40))
                    .foregroundStyle(AppBrand.accent)
                    .frame(width: 120, height: 90)
                    .background(AppBrand.accentTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppBrand.amber)
                    .offset(x: 6, y: -6)
            }

            VStack(spacing: 6) {
                Text(hasPastTrips ? "Nothing coming up" : "No trips yet")
                    .font(.title3.weight(.semibold))
                Text("Pick a few destinations and \(AppBrand.name) will find the days with the best weather across all of them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                router.selection = .explore
            } label: {
                Text(hasPastTrips ? "Plan your next trip" : "Plan your first trip")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppBrand.tealTop, in: Capsule())
            }
            .buttonStyle(.plain)

            if hasPastTrips {
                Button {
                    router.selection = .memories
                } label: {
                    Label("See past trips in Memories", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppBrand.link)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var hasPastTrips: Bool {
        trips.count > activeUpcomingTrips.count
    }

    private func delete(_ trip: Itinerary) {
        Task {
            do {
                try await TripRepository(context: context).deleteTrip(trip)
            } catch {
                // A plain cancel returns nil: the trip simply stays
                errorMessage = DestructiveActionGuard.userMessage(for: error, noun: "the trip")
            }
        }
    }
}

#Preview {
    TripListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(TabRouter())
}
