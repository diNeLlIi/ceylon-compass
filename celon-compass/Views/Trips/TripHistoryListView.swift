//
//  TripHistoryListView.swift
//  celon-compass
//
//  Past trips, shown under the History tab in Memories
//

import SwiftUI
import CoreData

struct TripHistoryListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Itinerary.startDate, ascending: false)],
        animation: .default
    ) private var trips: FetchedResults<Itinerary>

    @State private var tripPendingDelete: Itinerary?
    @State private var errorMessage: String?

    private var historyTrips: [Itinerary] {
        trips.filter { trip in
            guard let endDate = trip.endDate else { return false }
            return endDate < Calendar.current.startOfDay(for: .now)
        }
    }

    var body: some View {
        Group {
            if historyTrips.isEmpty {
                emptyState
            } else {
                historyList
            }
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

    private var historyList: some View {
        ScrollView {
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
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No past trips yet",
            systemImage: "clock.arrow.circlepath",
            description: Text("Trips move here once their last day has passed.")
        )
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
    NavigationStack {
        TripHistoryListView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
