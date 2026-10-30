//
//  CompleteTripSheet.swift
//  celon-compass
//
//  Review sheet for completing a trip: rate stops, add notes and photos.
//  One section per stop in sortOrder. Vision processes photos inline
//
//

import PhotosUI
import SwiftUI

struct CompleteTripSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var model: CompleteTripViewModel

    init(trip: Itinerary) {
        _model = State(initialValue: CompleteTripViewModel(trip: trip))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    ForEach(model.reviews.indices, id: \.self) { index in
                        stopSection(index: index)
                    }
                    saveButton
                }
                .padding()
            }
            .background(AppBrand.canvas)
            .navigationTitle("Complete Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { model.error != nil },
                set: { if !$0 { model.error = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.error ?? "")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How was your trip?")
                .font(.title2.bold())
            if let title = model.trip.title {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let start = model.trip.startDate, let end = model.trip.endDate {
                Text("\(start, format: .dateTime.month().day()) – \(end, format: .dateTime.month().day())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stopSection(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stop name + category
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.reviews[index].stop.poiName ?? "Stop \(index + 1)")
                        .font(.headline)
                    if let category = model.reviews[index].stop.poiCategory {
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let date = model.reviews[index].stop.date {
                    Text(date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            starRating(index: index)

            TextField("Add a note…", text: $model.reviews[index].note, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)

            // Photo picker
            photoRow(index: index)
        }
        .padding(16)
        .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func starRating(index: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= model.reviews[index].rating ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(star <= model.reviews[index].rating ? AppBrand.amber : .secondary)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            model.reviews[index].rating = Int16(star)
                        }
                    }
                    .sensoryFeedback(.selection, trigger: model.reviews[index].rating)
            }
        }
    }

    @ViewBuilder
    private func photoRow(index: Int) -> some View {
        if let photo = model.reviews[index].photo {
            VStack(alignment: .leading, spacing: 6) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if model.reviews[index].isProcessing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Analysing photo…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let vr = model.reviews[index].visionResult {
                    if let name = vr.suggestedStopName {
                        let confidence = vr.matchConfidence
                        Text(confidence > 0.5 ? name : "Is this \(name)?")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    if let ocrText = vr.recognisedText {
                        Text("Recognised: \(ocrText.prefix(80))\(ocrText.count > 80 ? "…" : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            PhotosPicker(
                selection: $model.reviews[index].photoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Add photo", systemImage: "camera")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppBrand.link)
            }
            .onChange(of: model.reviews[index].photoItem) {
                Task { await model.loadPhoto(for: index) }
            }
        }
    }

    private var saveButton: some View {
        Button(action: {
            Task {
                await model.save()
                if model.error == nil { dismiss() }
            }
        }) {
            Group {
                if model.isSaving {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Saving…")
                    }
                } else {
                    Text("Save memories")
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(AppBrand.tealTop, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(model.isSaving)
        .padding(.top, 8)
    }
}
