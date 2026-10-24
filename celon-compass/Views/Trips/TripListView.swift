//
//  TripListView.swift
//  celon-compass
//

import SwiftUI
import CoreData

struct TripListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Itinerary.createdAt, ascending: false)],
        animation: .default
    ) private var trips: FetchedResults<Itinerary>

    @State private var tripPendingDelete: Itinerary?
    @State private var isAddingTrip = false
    @State private var newTripTitle = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No trips yet",
                        systemImage: "map",
                        description: Text("Tap + to plan your first trip around Sri Lanka.")
                    )
                } else {
                    List {
                        ForEach(trips) { trip in
                            TripRow(trip: trip)
                        
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        tripPendingDelete = trip
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                                .listRowBackground(AppBrand.card)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppBrand.canvas)
            .navigationTitle("My Trips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("trips.add")
                }
            }
            .alert("New Trip", isPresented: $isAddingTrip) {
                TextField("Trip name", text: $newTripTitle)
                Button("Create") { createTrip() }
                Button("Cancel", role: .cancel) { newTripTitle = "" }
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

    private func createTrip() {
        let trimmed = newTripTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        newTripTitle = ""
        do {
            try TripRepository(context: context).createTrip(title: trimmed.isEmpty ? "Untitled trip" : trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
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

private struct TripRow: View {
    let trip: Itinerary

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "map.fill")
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    AppBrand.tealTop.gradient,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(trip.title ?? "Untitled trip")
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        let count = trip.stops?.count ?? 0
        let stops = count == 1 ? "1 stop" : "\(count) stops"
        guard let created = trip.createdAt else { return stops }
        return "\(stops) · \(created.formatted(date: .abbreviated, time: .omitted))"
    }
}

#Preview {
    TripListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
