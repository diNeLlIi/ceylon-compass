//
//  RescheduleStopSheet.swift
//  celon-compass
//
//  Tapping a stop in the itinerary opens this to move its date. The trip's own
//  start/end dates are derived from its stops, so this is also how the trip's
//  date range gets edited.

import SwiftUI

struct RescheduleStopSheet: View {
    let stop: ItineraryStop
    let onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(stop: ItineraryStop, onSave: @escaping (Date) -> Void) {
        self.stop = stop
        self.onSave = onSave
        _date = State(initialValue: stop.date ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            .navigationTitle(stop.poiName ?? "Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(date)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
