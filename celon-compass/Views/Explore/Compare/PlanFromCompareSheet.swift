//
//  PlanFromCompareSheet.swift
//  celon-compass
//
//

import SwiftUI
import CoreData

struct PlanFromCompareSheet: View {
    let destinations: [Destination]
    let dayRange: [Date]
    let onCreated: (Itinerary) -> Void

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip name") {
                    TextField("Trip name", text: $title)
                }
                Section {
                    ForEach(stopPreview, id: \.0.id) { pair in
                        HStack {
                            Text(pair.0.name ?? "Unknown")
                            Spacer()
                            Text(pair.1, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Stops")
                } footer: {
                    Text("One stop per destination, spread across the recommended window. You can reorder and change dates on the itinerary.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(AppBrand.destructive)
                    }
                }
            }
            .navigationTitle("Plan trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(isSaving || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if title.isEmpty {
                    title = defaultTitle
                }
            }
        }
    }

    private var defaultTitle: String {
        let names = destinations.compactMap(\.name)
        if names.isEmpty { return "Sri Lanka trip" }
        if names.count == 1 { return "\(names[0]) trip" }
        return names.joined(separator: " & ")
    }

 
    private var stopPreview: [(Destination, Date)] {
        guard !destinations.isEmpty, !dayRange.isEmpty else { return [] }
        return destinations.enumerated().map { index, destination in
            let dayIndex = min(index, dayRange.count - 1)
            return (destination, dayRange[dayIndex])
        }
    }

    private func create() {
        let repository = TripRepository(context: context)
        isSaving = true
        defer { isSaving = false }

        do {
            let trip = try repository.createTrip(title: title.trimmingCharacters(in: .whitespaces))
            trip.startDate = dayRange.first
            trip.endDate = dayRange.last
            for (index, pair) in stopPreview.enumerated() {
                let poi = POI(destination: pair.0)
                try repository.addStop(to: trip, poi: poi, date: pair.1, sortIndex: Int16(index))
            }
            onCreated(trip)
            dismiss()
        } catch {
            errorMessage = "Couldn't create the trip. Try again."
        }
    }
}
