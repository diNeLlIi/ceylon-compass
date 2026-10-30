//
//  CompleteTripViewModel.swift
//  celon-compass
//
//  Drives the Complete Trip review sheet.
//  Save rule: write a VisitRecord only if rating > 0 || note is non-empty || photo != nil.
//  Always set completedAt regardless.
//

import CoreData
import CoreLocation
import PhotosUI
import SwiftUI
import UIKit
import WidgetKit

@MainActor
@Observable
final class CompleteTripViewModel {
    let trip: Itinerary
    private let context: NSManagedObjectContext
    private let vision: any VisionProcessing
    private let locationService: LocationService

    struct StopReview: Identifiable {
        let stop: ItineraryStop
        var rating: Int16 = 0
        var note: String = ""
        var photo: UIImage?
        var photoItem: PhotosPickerItem?
        var visionResult: VisionResult?
        var isProcessing = false

        var id: NSManagedObjectID { stop.objectID }
        var hasContent: Bool { rating > 0 || !note.isEmpty || photo != nil }
    }

    var reviews: [StopReview] = []
    var isSaving = false
    var error: String?

    init(
        trip: Itinerary,
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
        vision: any VisionProcessing = VisionService.shared,
        locationService: LocationService = LocationService()
    ) {
        self.trip = trip
        self.context = context
        self.vision = vision
        self.locationService = locationService

        let stops = ((trip.stops as? Set<ItineraryStop>) ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
        reviews = stops.map { StopReview(stop: $0) }
    }

    func loadPhoto(for index: Int) async {
        guard let item = reviews[index].photoItem else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        reviews[index].photo = image
        await processVision(for: index, image: image)
    }

    private func processVision(for index: Int, image: UIImage) async {
        reviews[index].isProcessing = true
        defer { reviews[index].isProcessing = false }

        let stop = reviews[index].stop
        let coordinate = CLLocationCoordinate2D(
            latitude: stop.poiLatitude,
            longitude: stop.poiLongitude
        )

        do {
            let result = try await vision.process(image: image, near: coordinate)
            reviews[index].visionResult = result
        } catch {
            // Vision failure is non-fatal — the photo still saves, just without AI enrichment
        }
    }

    func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            for review in reviews where review.hasContent {
                let stop = review.stop
                let record = VisitRecord(context: context)
                record.id = UUID()
                record.destination = stop.destination
                record.stopName = stop.poiName
                record.visitDate = stop.date
                record.capturedAt = review.photo != nil ? Date() : nil
                record.latitude = stop.poiLatitude
                record.longitude = stop.poiLongitude
                record.rating = review.rating

                // Photo data
                if let photo = review.photo {
                    record.photoData = photo.jpegData(compressionQuality: 0.8)
                }

                // Vision results
                if let vr = review.visionResult {
                    record.thumbnailData = vr.thumbnail
                    record.suggestedStopName = vr.suggestedStopName
                    record.matchConfidence = vr.matchConfidence

                    // OCR note
                    if let ocrText = vr.recognisedText, !ocrText.isEmpty {
                        let ocrNote = TravelNote(context: context)
                        ocrNote.id = UUID()
                        ocrNote.text = ocrText
                        ocrNote.source = "ocr"
                        ocrNote.createdAt = Date()
                        ocrNote.touch()
                        record.note = ocrNote
                    }
                }

                // Manual note (takes precedence over OCR if both exist)
                if !review.note.isEmpty {
                    let manualNote = record.note ?? TravelNote(context: context)
                    if manualNote.id == nil { manualNote.id = UUID() }
                    // If OCR already wrote text, append manual note
                    if let existing = manualNote.text, !existing.isEmpty, manualNote.source == "ocr" {
                        manualNote.text = existing + "\n\n" + review.note
                        manualNote.source = "manual"
                    } else {
                        manualNote.text = review.note
                        manualNote.source = "manual"
                    }
                    manualNote.createdAt = Date()
                    manualNote.touch()
                    record.note = manualNote
                }

                record.touch()
            }

            // Always set completedAt
            trip.completedAt = Date()
            trip.touch()

            try context.save()
            SyncCoordinator.shared.enqueue()
            WidgetCenter.shared.reloadAllTimelines()

            // Clean up geofences for this trip
            let stops = ((trip.stops as? Set<ItineraryStop>) ?? [])
                .sorted { $0.sortOrder < $1.sortOrder }
            locationService.stopMonitoring(stops)

        } catch {
            context.rollback()
            self.error = "Couldn't save your memories. Please try again."
        }
    }
}
