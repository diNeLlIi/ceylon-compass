//
//  MemoryEditSheet.swift
//  celon-compass
//
//  Edits the rating/note on a memory, reached via the Edit swipe action.

import SwiftUI

struct MemoryEditSheet: View {
    let record: VisitRecord

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draftRating: Int16 = 0
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.stopName ?? "Unknown place")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppBrand.heading)
                    if let date = record.capturedAt ?? record.visitDate {
                        Text(date.formatted(.dateTime.day().month(.wide).year()))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            draftRating = Int16(star)
                        } label: {
                            Image(systemName: star <= Int(draftRating) ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundStyle(AppBrand.amber)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Rate \(star) of 5")
                    }
                }

                TextField("Add a note", text: $note, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(3...8)
                    .textFieldStyle(.roundedBorder)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Edit memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
        .onAppear {
            draftRating = record.rating
            note = record.note?.text ?? ""
        }
        .presentationDetents([.medium])
    }

    private func save() {
        try? VisitLogger(context: context).update(
            record,
            rating: draftRating,
            note: note.isEmpty ? nil : note
        )
        dismiss()
    }
}
