//
//  ContentView.swift
//  celon-compass
//
//  Created by student2 on 2026-09-30.
//

import SwiftUI
import CoreData

struct ContentView: View {
    var body: some View {
        TabView {
            
            TripListView()
                .tabItem { Label("Trips", systemImage: "map") }
            
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
            
        }
        .tint(AppBrand.tealTop)
        .task {
            try? await AuthService.shared.signInAnonymouslyIfNeeded()
            try? await CatalogSeeder.seedIfNeeded()
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
