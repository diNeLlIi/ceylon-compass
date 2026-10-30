//
//  SyncService.swift
//  celon-compass
//
//  Push/pull for user data ↔ Firestore. Photos excluded.
//  Same injection pattern as WeatherServicing / RoutingServicing.
//

import CoreData
import FirebaseAuth
import FirebaseFirestore
import Foundation


//Protocol

protocol SyncServicing: Sendable {
    func pushPending() async throws
    func pullAll() async throws
}

final class SyncService: SyncServicing {
    private let context: NSManagedObjectContext
    private let db: Firestore

    init(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
        db: Firestore = Firestore.firestore()
    ) {
        self.context = context
        self.db = db
    }

    func pushPending() async throws {
        guard let user = Auth.auth().currentUser, !user.isAnonymous else { return }
        let userRef = db.collection("users").document(user.uid)

        try await MainActor.run {
            var ops: [(DocumentReference, [String: Any]?, Bool)] = []  // (ref, data, isDelete)

            // Tombstones first:a delete queued behind an upsert of the same path loses
            let tombstones = try fetchAll(Tombstone.self)
            for t in tombstones {
                let ref = db.document("\(userRef.path)/\(t.path)")
                ops.append((ref, nil, true))
            }

            // Profile
            if let profile = try fetchProfile(uid: user.uid), profile.pendingSync {
                ops.append((userRef, dictionary(for: profile), false))
            }

            // Trips + stops
            let pendingTrips = try fetchPending(Itinerary.self)
            for trip in pendingTrips {
                let remoteID = trip.remoteID ?? UUID().uuidString
                trip.remoteID = remoteID
                let tripRef = userRef.collection("trips").document(remoteID)
                ops.append((tripRef, dictionary(for: trip), false))

                let stops = (trip.stops as? Set<ItineraryStop>)?.filter(\.pendingSync) ?? []
                for stop in stops {
                    let stopRemoteID = stop.remoteID ?? UUID().uuidString
                    stop.remoteID = stopRemoteID
                    ops.append((tripRef.collection("stops").document(stopRemoteID),
                                dictionary(for: stop), false))
                }
            }

            // Favourites
            let pendingFavourites = try fetchPending(Favourite.self)
            for fav in pendingFavourites {
                let remoteID = fav.remoteID ?? UUID().uuidString
                fav.remoteID = remoteID
                ops.append((userRef.collection("favourites").document(remoteID),
                            dictionary(for: fav), false))
            }

            // Memories (VisitRecords)
            let pendingMemories = try fetchPending(VisitRecord.self)
            for record in pendingMemories {
                let remoteID = record.remoteID ?? UUID().uuidString
                record.remoteID = remoteID
                ops.append((userRef.collection("memories").document(remoteID),
                            dictionary(for: record), false))
            }

            // Batch commit, chunked at 450
            Task {
                for chunk in ops.chunked(size: 450) {
                    let batch = db.batch()
                    for (ref, data, isDelete) in chunk {
                        if isDelete {
                            batch.deleteDocument(ref)
                        } else if let data {
                            batch.setData(data, forDocument: ref, merge: true)
                        }
                    }
                    try await batch.commit()
                }

                // Success: clear pendingSync, delete flushed tombstones
                await MainActor.run {
                    for trip in pendingTrips { trip.pendingSync = false }
                    let allStops = pendingTrips.flatMap {
                        ($0.stops as? Set<ItineraryStop>)?.filter(\.pendingSync) ?? []
                    }
                    for stop in allStops { stop.pendingSync = false }
                    for fav in pendingFavourites { fav.pendingSync = false }
                    for record in pendingMemories { record.pendingSync = false }
                    if let profile = try? fetchProfile(uid: user.uid) {
                        profile.pendingSync = false
                    }
                    for t in tombstones { context.delete(t) }
                    try? context.save()
                }
            }
        }
    }

    func pullAll() async throws {
        guard let user = Auth.auth().currentUser, !user.isAnonymous else { return }
        let uid = user.uid
        let userRef = db.collection("users").document(uid)

        // Check if already pulled for this UID
        let pulledKey = "syncPulledUIDs"
        let pulledUIDs = UserDefaults.standard.stringArray(forKey: pulledKey) ?? []
        guard !pulledUIDs.contains(uid) else { return }

        // Pull profile
        let profileDoc = try await userRef.getDocument()
        if profileDoc.exists, let data = profileDoc.data() {
            await MainActor.run {
                applyProfilePull(data, uid: uid)
            }
        }

        // Pull trips + stops
        let tripsSnapshot = try await userRef.collection("trips").getDocuments()
        for tripDoc in tripsSnapshot.documents {
            let stopsSnapshot = try await tripDoc.reference.collection("stops").getDocuments()
            await MainActor.run {
                applyTripPull(tripDoc, stopDocs: stopsSnapshot.documents)
            }
        }

        // Pull favourites
        let favsSnapshot = try await userRef.collection("favourites").getDocuments()
        for favDoc in favsSnapshot.documents {
            await MainActor.run {
                applyFavouritePull(favDoc)
            }
        }

        // Pull memories
        let memoriesSnapshot = try await userRef.collection("memories").getDocuments()
        for memDoc in memoriesSnapshot.documents {
            await MainActor.run {
                applyMemoryPull(memDoc)
            }
        }

        await MainActor.run {
            try? context.save()
        }

        // Mark this UID as pulled
        var updated = pulledUIDs
        updated.append(uid)
        UserDefaults.standard.set(updated, forKey: pulledKey)
    }

    
    //DTO mappers

    private func dictionary(for trip: Itinerary) -> [String: Any] {
        [
            "title":      trip.title ?? "",
            "startDate":  Timestamp(date: trip.startDate ?? .distantPast),
            "endDate":    Timestamp(date: trip.endDate ?? .distantPast),
            "createdAt":  Timestamp(date: trip.createdAt ?? .distantPast),
            "completedAt": trip.completedAt.map { Timestamp(date: $0) } as Any,
            "status":     trip.status ?? "",
            "originName": trip.originName ?? "",
            "originLat":  trip.originLat,
            "originLon":  trip.originLon,
            "updatedAt":  Timestamp(date: trip.updatedAt ?? .distantPast)
        ]
    }

    private func dictionary(for stop: ItineraryStop) -> [String: Any] {
        [
            "sortOrder":    Int(stop.sortOrder),
            "date":         Timestamp(date: stop.date ?? .distantPast),
            "travelNotes":  stop.travelNotes ?? "",
            "poiName":      stop.poiName ?? "",
            "poiLatitude":  stop.poiLatitude,
            "poiLongitude": stop.poiLongitude,
            "poiCategory":  stop.poiCategory ?? "",
            "poiSource":    stop.poiSource ?? "catalog",
            "destinationID": stop.destination?.id?.uuidString ?? "",
            "updatedAt":    Timestamp(date: stop.updatedAt ?? .distantPast)
        ]
    }

    private func dictionary(for record: VisitRecord) -> [String: Any] {
        [
            "stopName":          record.stopName ?? "",
            "rating":            Int(record.rating),
            "capturedAt":        Timestamp(date: record.capturedAt ?? record.visitDate ?? .distantPast),
            "visitDate":         Timestamp(date: record.visitDate ?? .distantPast),
            "latitude":          record.latitude,
            "longitude":         record.longitude,
            "destinationID":     record.destination?.id?.uuidString ?? "",
            "suggestedStopName": record.suggestedStopName ?? "",
            "matchConfidence":   record.matchConfidence,
            "noteText":          record.note?.text ?? "",
            "noteSource":        record.note?.source ?? "manual",
            "updatedAt":         Timestamp(date: record.updatedAt ?? .distantPast)
            // photoData and thumbnailData deliberately excluded
        ]
    }

    private func dictionary(for fav: Favourite) -> [String: Any] {
        [
            "destinationId": fav.destinationId?.uuidString ?? "",
            "createdAt":     Timestamp(date: fav.createdAt ?? .distantPast),
            "updatedAt":     Timestamp(date: fav.updatedAt ?? .distantPast)
        ]
    }

    private func dictionary(for profile: UserProfile) -> [String: Any] {
        [
            "email":          profile.email ?? "",
            "displayName":    profile.displayName ?? "",
            "homeCity":       profile.homeCity ?? "",
            "interests":      profile.interests ?? "",
            "tempUnit":       profile.tempUnit ?? "celsius",
            "rainTolerance":  profile.rainTolerance ?? "medium",
            "isAnonymous":    profile.isAnonymous,
            "updatedAt":      Timestamp(date: profile.updatedAt ?? .distantPast)
        ]
    }

    @MainActor
    private func applyProfilePull(_ data: [String: Any], uid: String) {
        let remoteUpdated = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
        let profile: UserProfile
        if let existing = try? fetchProfile(uid: uid) {
            let localUpdated = existing.updatedAt ?? .distantPast
            guard remoteUpdated > localUpdated else { return }
            profile = existing
        } else {
            profile = UserProfile(context: context)
            profile.uid = uid
        }
        profile.email = data["email"] as? String
        profile.displayName = data["displayName"] as? String
        profile.homeCity = data["homeCity"] as? String
        profile.interests = data["interests"] as? String
        profile.tempUnit = data["tempUnit"] as? String ?? "celsius"
        profile.rainTolerance = data["rainTolerance"] as? String ?? "medium"
        profile.isAnonymous = data["isAnonymous"] as? Bool ?? false
        profile.updatedAt = remoteUpdated
        profile.pendingSync = false

        // Refresh the in-memory cache
        UserProfileStore.shared.ensureProfileRefresh()
    }

    @MainActor
    private func applyTripPull(_ tripDoc: QueryDocumentSnapshot, stopDocs: [QueryDocumentSnapshot]) {
        let data = tripDoc.data()
        let remoteID = tripDoc.documentID
        let remoteUpdated = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast

        let trip: Itinerary
        if let existing = try? fetchByRemoteID(Itinerary.self, remoteID: remoteID) {
            let localUpdated = existing.updatedAt ?? .distantPast
            if remoteUpdated <= localUpdated { return }
            trip = existing
        } else {
            trip = Itinerary(context: context)
            trip.id = UUID()
            trip.remoteID = remoteID
        }

        trip.title = data["title"] as? String
        trip.startDate = (data["startDate"] as? Timestamp)?.dateValue()
        trip.endDate = (data["endDate"] as? Timestamp)?.dateValue()
        trip.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        trip.completedAt = (data["completedAt"] as? Timestamp)?.dateValue()
        trip.status = data["status"] as? String
        trip.originName = data["originName"] as? String
        trip.originLat = data["originLat"] as? Double ?? 0
        trip.originLon = data["originLon"] as? Double ?? 0
        trip.updatedAt = remoteUpdated
        trip.pendingSync = false

        // Stops
        for stopDoc in stopDocs {
            let sData = stopDoc.data()
            let sRemoteID = stopDoc.documentID
            let sRemoteUpdated = (sData["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast

            let stop: ItineraryStop
            if let existing = try? fetchByRemoteID(ItineraryStop.self, remoteID: sRemoteID) {
                let localUpdated = existing.updatedAt ?? .distantPast
                if sRemoteUpdated <= localUpdated { continue }
                stop = existing
            } else {
                stop = ItineraryStop(context: context)
                stop.id = UUID()
                stop.remoteID = sRemoteID
                stop.itinerary = trip
            }

            stop.sortOrder = Int16(sData["sortOrder"] as? Int ?? 0)
            stop.date = (sData["date"] as? Timestamp)?.dateValue()
            stop.travelNotes = sData["travelNotes"] as? String
            stop.poiName = sData["poiName"] as? String
            stop.poiLatitude = sData["poiLatitude"] as? Double ?? 0
            stop.poiLongitude = sData["poiLongitude"] as? Double ?? 0
            stop.poiCategory = sData["poiCategory"] as? String
            stop.poiSource = sData["poiSource"] as? String ?? "catalog"
            stop.updatedAt = sRemoteUpdated
            stop.pendingSync = false

            // Re-link destination by UUID
            if let destIDString = sData["destinationID"] as? String,
               let destUUID = UUID(uuidString: destIDString) {
                stop.destination = try? fetchDestination(id: destUUID)
            }
        }
    }

    @MainActor
    private func applyFavouritePull(_ doc: QueryDocumentSnapshot) {
        let data = doc.data()
        let remoteID = doc.documentID
        let remoteUpdated = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast

        let fav: Favourite
        if let existing = try? fetchByRemoteID(Favourite.self, remoteID: remoteID) {
            let localUpdated = existing.updatedAt ?? .distantPast
            if remoteUpdated <= localUpdated { return }
            fav = existing
        } else {
            fav = Favourite(context: context)
            fav.id = UUID()
            fav.remoteID = remoteID
        }

        if let idString = data["destinationId"] as? String {
            fav.destinationId = UUID(uuidString: idString)
        }
        fav.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        fav.updatedAt = remoteUpdated
        fav.pendingSync = false
    }

    @MainActor
    private func applyMemoryPull(_ doc: QueryDocumentSnapshot) {
        let data = doc.data()
        let remoteID = doc.documentID
        let remoteUpdated = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast

        let record: VisitRecord
        if let existing = try? fetchByRemoteID(VisitRecord.self, remoteID: remoteID) {
            let localUpdated = existing.updatedAt ?? .distantPast
            if remoteUpdated <= localUpdated { return }
            record = existing
        } else {
            record = VisitRecord(context: context)
            record.id = UUID()
            record.remoteID = remoteID
        }

        record.stopName = data["stopName"] as? String
        record.rating = Int16(data["rating"] as? Int ?? 0)
        record.visitDate = (data["visitDate"] as? Timestamp)?.dateValue()
        record.capturedAt = (data["capturedAt"] as? Timestamp)?.dateValue()
        record.latitude = data["latitude"] as? Double ?? 0
        record.longitude = data["longitude"] as? Double ?? 0
        record.matchConfidence = data["matchConfidence"] as? Double ?? 0
        record.suggestedStopName = data["suggestedStopName"] as? String
        record.updatedAt = remoteUpdated
        record.pendingSync = false
        // photoData and thumbnailData stay nil — pulled memory has no photo

        // Note
        let noteText = data["noteText"] as? String ?? ""
        let noteSource = data["noteSource"] as? String ?? "manual"
        if !noteText.isEmpty {
            let note = record.note ?? TravelNote(context: context)
            if note.id == nil { note.id = UUID() }
            note.text = noteText
            note.source = noteSource
            note.updatedAt = remoteUpdated
            note.pendingSync = false
            record.note = note
        }

        // Re-link destination
        if let destIDString = data["destinationID"] as? String,
           let destUUID = UUID(uuidString: destIDString) {
            record.destination = try? fetchDestination(id: destUUID)
        }
    }

    
    //helpers

    @MainActor
    private func fetchAll<T: NSManagedObject>(_ type: T.Type) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        return try context.fetch(request)
    }

    @MainActor
    private func fetchPending<T: NSManagedObject>(_ type: T.Type) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = NSPredicate(format: "pendingSync == YES")
        return try context.fetch(request)
    }

    @MainActor
    private func fetchProfile(uid: String) throws -> UserProfile? {
        let request = UserProfile.fetchRequest()
        request.predicate = NSPredicate(format: "uid == %@", uid)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    @MainActor
    private func fetchByRemoteID<T: NSManagedObject>(_ type: T.Type, remoteID: String) throws -> T? {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = NSPredicate(format: "remoteID == %@", remoteID)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    @MainActor
    private func fetchDestination(id: UUID) throws -> Destination? {
        let request = Destination.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

extension Array {
    func chunked(size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
