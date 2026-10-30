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
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Itinerary.startDate, ascending: true)]
    ) private var trips: FetchedResults<Itinerary>

    private var completedCount: Int {
        trips.filter { $0.completedAt != nil }.count
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
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
