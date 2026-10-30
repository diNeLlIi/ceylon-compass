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

    private var activeUpcomingTrips: [Itinerary] {
        trips.filter(isActiveOrUpcoming)
    }

    private var historyTrips: [Itinerary] {
        trips.filter { !isActiveOrUpcoming($0) }
    }

    private func isActiveOrUpcoming(_ trip: Itinerary) -> Bool {
        guard let endDate = trip.endDate else { return true }
        return endDate >= Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    emptyState
                } else {
                    tripList
                }
            }
            .background(AppBrand.canvas)
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

    private var tripList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !activeUpcomingTrips.isEmpty {
                    sectionHeader("Active & Upcoming")
                    VStack(spacing: 14) {
                        ForEach(activeUpcomingTrips) { trip in
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

                if !historyTrips.isEmpty {
                    sectionHeader("Trip History")
                    VStack(spacing: 0) {
                        ForEach(Array(historyTrips.enumerated()), id: \.element.objectID) { index, trip in
                            NavigationLink(value: trip) {
                                TripHistoryRowView(trip: trip)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    tripPendingDelete = trip
                                } label: {
                                    Label("Delete Trip", systemImage: "trash")
                                }
                            }
                            if index < historyTrips.count - 1 {
                                Divider().padding(.leading, 66)
                            }
                        }
                    }
                    .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
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
                Text("No trips yet")
                    .font(.title3.weight(.semibold))
                Text("Pick a few destinations and WanderLanka will find the days with the best weather across all of them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                router.selection = .explore
            } label: {
                Text("Plan your first trip")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppBrand.tealTop, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func delete(_ trip: Itinerary) {
        Task {
            do {
                try await TripRepository(context: context).deleteTrip(trip)
            } catch {
                // A plain cancel returns nil: the trip simply stays.
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
