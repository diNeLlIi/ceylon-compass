//
//  FirestoreSubtree.swift
//  celon-compass
//
//  Client-side depth-first deletion of a Firestore document and its known subcollections
//

import FirebaseFirestore

enum FirestoreSubtree {
    private static let knownSubcollections: [String] = [
        "trips",
        "favourites",
        "memories"
    ]

    private static let tripSubcollections: [String] = [
        "stops"
    ]

    
    static func delete(under userRef: DocumentReference, db: Firestore) async throws {
        // Delete trip subcollections first (stops inside each trip)
        let tripsSnapshot = try await userRef.collection("trips").getDocuments()
        for tripDoc in tripsSnapshot.documents {
            for sub in tripSubcollections {
                try await deleteCollection(tripDoc.reference.collection(sub), db: db)
            }
        }

        // Delete top-level subcollections
        for collection in knownSubcollections {
            try await deleteCollection(userRef.collection(collection), db: db)
        }
    }

    // Deletes all documents in a collection, batched at 450
    private static func deleteCollection(_ ref: CollectionReference, db: Firestore) async throws {
        var snapshot = try await ref.getDocuments()
        while !snapshot.documents.isEmpty {
            let batch = db.batch()
            for (index, doc) in snapshot.documents.enumerated() {
                guard index < 450 else { break }
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()

            if snapshot.documents.count > 450 {
                snapshot = try await ref.getDocuments()
            } else {
                break
            }
        }
    }
}
