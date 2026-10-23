//
//  ContentView.swift
//  celon-compass
//
//  Created by student2 on 2026-09-30.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .task {
            try? await AuthService.shared.signInAnonymouslyIfNeeded()
            try? await CatalogSeeder.seedIfNeeded()
        }
    }
}

#Preview {
    ContentView()
}
