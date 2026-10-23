//
//  CatalogSeeder.swift
//  celon-compass
//
//  Created by student2 on 2026-10-23.
//

import FirebaseFirestore

struct CatalogSeeder {
    static func seedIfNeeded() async throws {
        guard !UserDefaults.standard.bool(forKey: "catalogSeeded") else { return }

        let destinations: [DestinationDTO] = try loadFromBundle("Destinations.json")
        let db = Firestore.firestore()

        for dest in destinations {
            try db.collection("destinations").document(dest.id).setData(from: dest)
        }
        UserDefaults.standard.set(true, forKey: "catalogSeeded")
    }
}
