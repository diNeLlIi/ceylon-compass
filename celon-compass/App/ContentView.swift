//
//  ContentView.swift
//  celon-compass
//
//  Created by student2 on 2026-09-30.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @State private var selection: AppTab = .trips

    init() {
        Self.configureTabBarAppearance()
    }

    var body: some View {
        TabView(selection: $selection) {
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
        .task {
            try? await AuthService.shared.signInAnonymouslyIfNeeded()
            try? await CatalogSeeder.seedIfNeeded()
        }
    }

    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppBrand.canvas)
        appearance.shadowColor = UIColor.separator

        let normal = UIColor.secondaryLabel
        let selected = UIColor(AppBrand.link)
        for item in [appearance.stackedLayoutAppearance,
                     appearance.inlineLayoutAppearance,
                     appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = normal
            item.normal.titleTextAttributes = [.foregroundColor: normal]
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = [.foregroundColor: selected]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
