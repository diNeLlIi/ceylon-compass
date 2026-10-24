//
//  AccountService.swift
//  celon-compass
//

import CoreData
import FirebaseAuth

@MainActor
struct AccountService {
    let context: NSManagedObjectContext
    private let guardian: DestructiveActionGuard
    private let deleteRemoteAccount: () async throws -> Void
    private let afterDeletion: () async -> Void

    init(
        context: NSManagedObjectContext,
        guardian: DestructiveActionGuard? = nil,
        deleteRemoteAccount: @escaping () async throws -> Void = {
            try await Auth.auth().currentUser?.delete()
        },
        afterDeletion: @escaping () async -> Void = {
            // Give the app a fresh anonymous identity so cloud-backed features keep working
            try? await AuthService.shared.signInAnonymouslyIfNeeded()
        }
    ) {
        self.context = context
        self.guardian = guardian ?? DestructiveActionGuard()
        self.deleteRemoteAccount = deleteRemoteAccount
        self.afterDeletion = afterDeletion
    }

    
    func deleteAccount() async throws {
        try await guardian.perform(reason: "Confirm deleting your account") {
            try await deleteRemoteAccount()
            try wipeUserData()
        }
        await afterDeletion()
    }

    private func wipeUserData() throws {
        do {
            for entityName in ["Itinerary", "ItineraryStop", "TravelNote", "VisitRecord", "WeatherSnapshot"] {
                let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                for object in try context.fetch(request) {
                    context.delete(object)
                }
            }
            // destinations are the seeded catalogue
            //only clear the user's favourite destinations
            for destination in try context.fetch(Destination.fetchRequest()) {
                destination.isFavourite = false
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
