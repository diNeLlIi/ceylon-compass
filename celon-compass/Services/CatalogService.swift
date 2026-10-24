//
//  CatalogService.swift
//  celon-compass
//
//  Created by student2 on 2026-10-23.
//

import FirebaseFirestore

protocol CatalogServiceProtocol {
    @MainActor
    func fetchDestinations() async throws -> [Destination]
    @MainActor
    func refreshFromRemote() async throws
}

final class CatalogService: CatalogServiceProtocol {
    // Strict refresh: reads from the server only and throws if that fails
    // Unlike `fetchDestinations()` it never falls back to the bundled catalogue
    @MainActor
    func refreshFromRemote() async throws {
        let snapshot = try await Firestore.firestore()
            .collection("destinations")
            .getDocuments(source: .server)
        let dtos = try snapshot.documents.map { try $0.data(as: DestinationDTO.self) }
        try CoreDataSync.upsert(dtos)
    }

    @MainActor
    func fetchDestinations() async throws -> [Destination] {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("destinations")
                .getDocuments()
            let dtos = try snapshot.documents.map { try $0.data(as: DestinationDTO.self) }
            try CoreDataSync.upsert(dtos)
            return CoreDataSync.fetchAll()
        } catch {
            let dtos: [DestinationDTO] = try loadFromBundle("Destinations.json")
            try CoreDataSync.upsert(dtos)
            return CoreDataSync.fetchAll()
        }
    }
}
