//
//  SyncDTOs.swift
//  celon-compass
//
//  Pure Codable DTOs for Firestore sync. Core Data - DTO is a pure function,
//  keeping the mapping unit-testable without a Firestore stub.
//

import Foundation

struct TripDTO: Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let createdAt: Date
    let completedAt: Date?
    let status: String
    let originName: String
    let originLat: Double
    let originLon: Double
    let updatedAt: Date
}

struct StopDTO: Codable {
    let id: String
    let sortOrder: Int
    let date: Date
    let travelNotes: String
    let poiName: String
    let poiLatitude: Double
    let poiLongitude: Double
    let poiCategory: String
    let poiSource: String
    let destinationID: String
    let updatedAt: Date
}

struct MemoryDTO: Codable {
    let id: String
    let stopName: String
    let rating: Int
    let visitDate: Date
    let capturedAt: Date
    let latitude: Double
    let longitude: Double
    let destinationID: String
    let suggestedStopName: String
    let matchConfidence: Double
    let noteText: String
    let noteSource: String
    let updatedAt: Date
    // photoData and thumbnailData deliberately excluded
}

struct FavouriteDTO: Codable {
    let id: String
    let destinationId: String
    let createdAt: Date
    let updatedAt: Date
}

struct UserProfileDTO: Codable {
    let uid: String
    let email: String?
    let displayName: String?
    let homeCity: String
    let interests: String
    let tempUnit: String
    let rainTolerance: String
    let isAnonymous: Bool
    let updatedAt: Date
}
