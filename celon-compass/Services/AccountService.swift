//
//  AccountService.swift
//  celon-compass
//
//  Orchestrates account deletion in the correct order:
//  1. Firestore subtree cleanup (while auth still valid)
//  2. Auth user deletion
//  3. Local Core Data wipe
//  4. Fresh anonymous session
//

import CoreData
import FirebaseAuth
import FirebaseFirestore

@MainActor
struct AccountService {
    let context: NSManagedObjectContext
    private let guardian: DestructiveActionGuard
    private let deleteRemoteAccount: () async throws -> Void
    private let afterDeletion: () async -> Void

    init(
        context: NSManagedObjectContext,
        guardian: DestructiveActionGuard? = nil,
        deleteRemoteAccount: (() async throws -> Void)? = nil,
        afterDeletion: (() async -> Void)? = nil
    ) {
        self.context = context
        self.guardian = guardian ?? DestructiveActionGuard()
        self.deleteRemoteAccount = deleteRemoteAccount ?? {
            // Default: Firestore subtree → user doc → auth user
            let auth = AuthService.shared
            if let uid = Auth.auth().currentUser?.uid, !auth.isAnonymous {
                let db = Firestore.firestore()
                let userRef = db.collection("users").document(uid)
                try await FirestoreSubtree.delete(under: userRef, db: db)
                try await userRef.delete()
            }
            try await auth.deleteAuthUser()
        }
        self.afterDeletion = afterDeletion ?? {
            try? await AuthService.shared.signInAnonymouslyIfNeeded()
            try? UserProfileStore.shared.ensureProfile()
        }
    }

    func deleteAccount() async throws {
        try await guardian.perform(reason: "Confirm deleting your account") {
            try await deleteRemoteAccount()
            try wipeLocalStore()
        }
        await afterDeletion()
    }

    private func wipeLocalStore() throws {
        do {
            for entityName in [
                "Itinerary", "ItineraryStop", "TravelNote", "VisitRecord",
                "WeatherSnapshot", "Favourite", "UserProfile", "Tombstone"
            ] {
                let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                for object in try context.fetch(request) {
                    context.delete(object)
                }
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
