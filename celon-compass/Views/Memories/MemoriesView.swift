//
//  MemoriesView.swift
//  celon-compass
//

import SwiftUI
internal import CoreData

struct MemoriesView: View {
    private enum MemoriesSection: String, CaseIterable, Identifiable {
        case memories = "Memories"
        case history = "History"

        var id: String { rawValue }
    }

    @State private var section: MemoriesSection = .memories

    var body: some View {
        NavigationStack {
            Group {
                switch section {
                case .memories: memoriesPlaceholder
                case .history: TripHistoryListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBrand.canvas)
            
            .safeAreaInset(edge: .top) {
                Picker("Section", selection: $section) {
                    ForEach(MemoriesSection.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(AppBrand.canvas)
            }
            .navigationTitle("Memories")
            .navigationBarTitleDisplayMode(.inline)
            .brandToolbar()
            .navigationDestination(for: Itinerary.self) { trip in
                ItineraryView(trip: trip)
            }
        }
    }

    private var memoriesPlaceholder: some View {
        ContentUnavailableView(
            "Memories are coming soon",
            systemImage: "square.on.square",
            description: Text("Keep your notes and photos from every place you've visited.")
        )
    }
}

#Preview {
    MemoriesView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
