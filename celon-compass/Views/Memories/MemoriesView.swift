//
//  MemoriesView.swift
//  celon-compass
//

import SwiftUI
import CoreData

struct MemoriesView: View {
    private enum MemoriesSection: String, CaseIterable, Identifiable {
        case memories = "Memories"
        case history = "History"

        var id: String { rawValue }
    }

    @State private var section: MemoriesSection = .memories
    @Environment(\.isRegularWidth) private var isRegularWidth
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VisitRecord.visitDate, ascending: false)],
        animation: .default
    ) private var records: FetchedResults<VisitRecord>

    @State private var openCardID: NSManagedObjectID?
    @State private var editingRecord: VisitRecord?
    @State private var recordPendingDelete: VisitRecord?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                switch section {
                case .memories: memoriesContent
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
            .sheet(item: $editingRecord) { record in
                MemoryEditSheet(record: record)
            }
            .confirmationDialog(
                "Delete this memory?",
                isPresented: Binding(
                    get: { recordPendingDelete != nil },
                    set: { if !$0 { recordPendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Memory", role: .destructive) {
                    if let record = recordPendingDelete { delete(record) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert(
                "Memory not deleted",
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

    private func delete(_ record: VisitRecord) {
        do {
            try VisitLogger(context: context).delete(record)
        } catch {
            errorMessage = "Couldn't delete this memory. Try again."
        }
    }

    @ViewBuilder
    private var memoriesContent: some View {
        let memoriesWithContent = records.filter { $0.rating > 0 || $0.note != nil || $0.photoData != nil }
        if memoriesWithContent.isEmpty {
            memoriesPlaceholder
        } else {
            ScrollView {
                // One column on iPhone, adaptive on iPad: a single column of memory cards
                // at 13" leaves most of the screen empty.
                LazyVGrid(columns: memoryColumns, spacing: 12) {
                    ForEach(memoriesWithContent, id: \.objectID) { record in
                        SwipeActionsCard(
                            id: record.objectID,
                            openID: $openCardID,
                            actions: [
                                SwipeAction(title: "Edit", systemImage: "pencil", tint: AppBrand.link) {
                                    editingRecord = record
                                },
                                SwipeAction(title: "Delete", systemImage: "trash", tint: AppBrand.destructive, role: .destructive) {
                                    recordPendingDelete = record
                                }
                            ]
                        ) {
                            MemoryCard(record: record)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
    }

    private var memoryColumns: [GridItem] {
        isRegularWidth
            ? [GridItem(.adaptive(minimum: 320), spacing: 12)]
            : [GridItem(.flexible())]
    }

    private var memoriesPlaceholder: some View {
        ContentUnavailableView(
            "No memories yet",
            systemImage: "square.on.square",
            description: Text("Complete a trip and rate your stops to start building memories.")
        )
    }
}

//Memory Card

private struct MemoryCard: View {
    let record: VisitRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            imageSlot
            HStack {
                Text(record.stopName ?? "Unknown place")
                    .font(.headline)
                Spacer()
                starDisplay
            }

            // Date
            if let date = record.capturedAt ?? record.visitDate {
                Text(date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Note
            if let noteText = record.note?.text, !noteText.isEmpty {
                Text(noteText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            // Vision suggestion
            if let suggestion = record.suggestedStopName {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text(record.matchConfidence > 0.5 ? suggestion : "Might be \(suggestion)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var imageSlot: some View {
        if let thumbnailData = record.thumbnailData, let image = UIImage(data: thumbnailData) {
            // Case 1: saliency crop
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if let photoData = record.photoData, let image = UIImage(data: photoData) {
            // Case 2: full image
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if record.remoteID != nil {
            // Case 3: pulled from Firebase, photo on original device
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray5))
                    .frame(height: 100)
                VStack(spacing: 6) {
                    Image(systemName: categoryIcon)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Photo saved on original device")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        // Case 4: local memory with no photo — no image slot at all
    }

    private var starDisplay: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= record.rating ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(star <= record.rating ? AppBrand.amber : Color(.systemGray4))
            }
        }
    }

    private var categoryIcon: String {
        guard let dest = record.destination, let category = dest.category else {
            return "mappin.circle"
        }
        switch category.lowercased() {
        case "beach": return "water.waves"
        case "mountain": return "mountain.2"
        case "heritage": return "building.columns"
        case "wildlife": return "pawprint"
        case "waterfalls": return "drop.triangle"
        case "temples": return "building"
        default: return "mappin.circle"
        }
    }
}

#Preview {
    MemoriesView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
