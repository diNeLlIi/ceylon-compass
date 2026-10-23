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
}

final class CatalogService: CatalogServiceProtocol {
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
