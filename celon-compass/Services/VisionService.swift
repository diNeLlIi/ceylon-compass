//
//  VisionService.swift
//  celon-compass
//
//  Three Vision pipelines in one VNImageRequestHandler pass:
//  1. Saliency crop → thumbnailData (JPEG)
//  2. Feature print + GPS → suggestedStopName + matchConfidence
//  3. OCR → TravelNote(source: "ocr"), English only
//

import CoreLocation
import UIKit
import Vision
import CoreData

struct VisionResult {
    let thumbnail: Data?
    let suggestedStopName: String?
    let matchConfidence: Double
    let recognisedText: String?
}

protocol VisionProcessing: Sendable {
    func process(image: UIImage, near coordinate: CLLocationCoordinate2D?) async throws -> VisionResult
}

final class VisionService: VisionProcessing {
    static let shared = VisionService()

    func process(image: UIImage, near coordinate: CLLocationCoordinate2D?) async throws -> VisionResult {
        guard let cgImage = image.cgImage else {
            return VisionResult(thumbnail: nil, suggestedStopName: nil, matchConfidence: 0, recognisedText: nil)
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // 1. Saliency
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()

        // 2. Feature print
        let featurePrintRequest = VNGenerateImageFeaturePrintRequest()

        // 3. OCR
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.recognitionLanguages = ["en-US"]

        try handler.perform([saliencyRequest, featurePrintRequest, textRequest])

        // Process saliency → crop → JPEG thumbnail
        let thumbnail = saliencyCrop(from: cgImage, request: saliencyRequest)

        // Process feature print → place match
        let (suggestedName, confidence) = matchPlace(
            featurePrintRequest: featurePrintRequest,
            near: coordinate
        )

        // Process OCR
        let text = extractText(from: textRequest)

        return VisionResult(
            thumbnail: thumbnail,
            suggestedStopName: suggestedName,
            matchConfidence: confidence,
            recognisedText: text
        )
    }

    
    //Pipeline 1: Saliency crop

    private func saliencyCrop(from cgImage: CGImage, request: VNGenerateAttentionBasedSaliencyImageRequest) -> Data? {
        guard let observation = request.results?.first,
              let salientObject = observation.salientObjects?.first else { return nil }

        let box = salientObject.boundingBox
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // VNBoundingBox is normalised, origin bottom-left
        let cropRect = CGRect(
            x: box.origin.x * imageWidth,
            y: (1 - box.origin.y - box.height) * imageHeight,
            width: box.width * imageWidth,
            height: box.height * imageHeight
        ).integral

        guard !cropRect.isEmpty,
              let cropped = cgImage.cropping(to: cropRect) else { return nil }

        // Scale to a reasonable thumbnail size
        let maxDimension: CGFloat = 300
        let scale = min(maxDimension / CGFloat(cropped.width), maxDimension / CGFloat(cropped.height), 1)
        let size = CGSize(width: CGFloat(cropped.width) * scale, height: CGFloat(cropped.height) * scale)

        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnailImage = renderer.image { _ in
            UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: size))
        }
        return thumbnailImage.jpegData(compressionQuality: 0.7)
    }

    
    //Pipeline 2: Feature print place match

    private func matchPlace(
        featurePrintRequest: VNGenerateImageFeaturePrintRequest,
        near coordinate: CLLocationCoordinate2D?
    ) -> (String?, Double) {
        guard let inputPrint = featurePrintRequest.results?.first else {
            return (nil, 0)
        }

        // GPS-primary: narrow to catalog destinations within approximately 25 km
        // Feature print is a tie-break with matchConfidence capped at 0.5
        // when nothing is cached. Full implementation requires cached reference images
        // from the Explore pipeline (URLCache). For now,  GPS-nearest with 0.5 cap returns
        guard let coordinate else { return (nil, 0) }

        // Find nearest catalog destination by GPS: this is a placeholder that will
        // be enhanced when reference feature prints are cached from Explore's image loading
        let nearestName = findNearestCatalogDestination(near: coordinate)
        let confidence = nearestName != nil ? 0.5 : 0.0

        return (nearestName, confidence)
    }

    private func findNearestCatalogDestination(near coordinate: CLLocationCoordinate2D) -> String? {
        let context = PersistenceController.shared.container.viewContext
        let request = Destination.fetchRequest()
        let destinations = (try? context.fetch(request)) ?? []

        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let maxDistance: CLLocationDistance = 25_000 // 25 km

        var nearest: (name: String, distance: CLLocationDistance)?
        for dest in destinations {
            let loc = CLLocation(latitude: dest.latitude, longitude: dest.longitude)
            let dist = userLocation.distance(from: loc)
            if dist < maxDistance {
                if nearest == nil || dist < nearest!.distance {
                    nearest = (dest.name ?? "Unknown", dist)
                }
            }
        }
        return nearest?.name
    }

    
    //Pipeline 3: OCR

    private func extractText(from request: VNRecognizeTextRequest) -> String? {
        guard let observations = request.results, !observations.isEmpty else { return nil }

        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text.isEmpty ? nil : text
    }
}
