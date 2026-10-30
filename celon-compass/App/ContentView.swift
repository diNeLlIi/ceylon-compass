//
//  ContentView.swift
//  celon-compass
//
//  Created by student2 on 2026-09-30.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @State private var router = TabRouter()
    @State private var locationService = LocationService()
    @State private var deepLinkedTrip: Itinerary?
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Itinerary.startDate, ascending: true)]
    ) private var trips: FetchedResults<Itinerary>

    @Environment(\.managedObjectContext) private var viewContext

    private var completedCount: Int {
        trips.filter { $0.completedAt != nil }.count
    }

    private var inbox: DeepLinkInbox { .shared }

    private func handle(_ link: DeepLink) {
        router.selection = .trips
        switch link {
        case .trips:
            deepLinkedTrip = nil
        case .trip(let id):
            // A widget timeline or a Shortcut can outlive the trip it names, so an
            // unmatched id falls back to the list rather than presenting nothing.
            deepLinkedTrip = trips.first { $0.id == id }
        }
    }

    // Changes whenever a trip is added, removed, completed, renamed or rescheduled.
    private var reminderSignature: String {
        trips
            .map { "\($0.id?.uuidString ?? "")|\($0.startDate?.timeIntervalSince1970 ?? 0)|\($0.endDate?.timeIntervalSince1970 ?? 0)|\($0.completedAt != nil)" }
            .joined(separator: ",")
            + "|\(PreferencesStore.shared.tripRemindersEnabled)"
    }

    var body: some View {
        TabView(selection: $router.selection) {
            Tab(AppTab.explore.title, systemImage: AppTab.explore.symbol, value: AppTab.explore) {
                ExploreView()
            }
            Tab(AppTab.map.title, systemImage: AppTab.map.symbol, value: AppTab.map) {
                MapTabView()
            }
            Tab(AppTab.trips.title, systemImage: AppTab.trips.symbol, value: AppTab.trips) {
                TripListView()
            }
            Tab(AppTab.memories.title, systemImage: AppTab.memories.symbol, value: AppTab.memories) {
                MemoriesView()
            }
            Tab(AppTab.settings.title, systemImage: AppTab.settings.symbol, value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(AppBrand.link)
        .toolbarBackground(AppBrand.canvas, for: .tabBar)
        .toolbarBackgroundVisibility(.visible, for: .tabBar)
        .environment(router)
        .onOpenURL { url in
            guard let link = DeepLink(url: url) else { return }
            handle(link)
        }
        .onChange(of: inbox.pending) { _, link in
            guard let link else { return }
            inbox.pending = nil
            handle(link)
        }
        .sheet(item: $deepLinkedTrip) { trip in
            NavigationStack {
                ItineraryView(trip: trip)
            }
        }
        .task {
            try? await AuthService.shared.signInAnonymouslyIfNeeded()
            try? UserProfileStore.shared.ensureProfile()
            try? await CatalogSeeder.seedIfNeeded()
        }
        .task(id: "\(trips.count)-\(completedCount)-\(PreferencesStore.shared.tripRemindersEnabled)") {
            guard PreferencesStore.shared.tripRemindersEnabled,
                  let trip = ActiveTripResolver.current(Array(trips))
            else { return }
            locationService.requestAlways()
            let stops = ((trip.stops as? Set<ItineraryStop>) ?? [])
                .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
            locationService.monitorStops(stops)
        }
        // Keyed on the same signature as the geofence task, so creating, editing,
        // deleting or completing a trip all rebuild the pending reminders.
        .task(id: reminderSignature) {
            await TripReminderScheduler.reschedule(trips: Array(trips), context: viewContext)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
