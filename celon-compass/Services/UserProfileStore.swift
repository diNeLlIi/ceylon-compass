//
//  UserProfileStore.swift
//  celon-compass
//
//  Core Data–backed singleton for user profile preferences.
//  Synced keys (homeCity, interests, tempUnit, rainTolerance)
//

import CoreData
import FirebaseAuth
import Foundation
import Observation

enum RainTolerance: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }
    var label: String {
        switch self {
        case .low: "Low — I'll skip rainy days"
        case .medium: "Medium — light rain is fine"
        case .high: "High — rain won't stop me"
        }
    }
}

@MainActor
@Observable
final class UserProfileStore {
    static let shared = UserProfileStore()

    @ObservationIgnored
    private let context: NSManagedObjectContext

    // Cached from the Core Data row so reads are synchronous.
    private(set) var homeCity: String = ""
    private(set) var interests: Set<TravelInterest> = []
    private(set) var temperatureUnit: TemperatureUnit = .celsius
    private(set) var rainTolerance: RainTolerance = .medium
    private(set) var email: String?
    private(set) var displayName: String?
    private(set) var isAnonymous: Bool = true

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        loadCached()
    }
    
//Profile lifecycle

    // Creates a profile row for the current anonymous UID if none exists
    // Idempotent:safe to call on every launch.
    func ensureProfile() throws {
        let uid = Auth.auth().currentUser?.uid ?? ""
        if let existing = try fetchProfile(uid: uid) {
            refreshCache(from: existing)
            return
        }
        let profile = UserProfile(context: context)
        profile.uid = uid
        profile.isAnonymous = Auth.auth().currentUser?.isAnonymous ?? true
        // Seed from UserDefaults if the user already onboarded before this migration.
        seedFromDefaults(profile)
        profile.touch()
        try save()
        refreshCache(from: profile)
    }

    //Setters (called from PreferencesStore delegates)

    func setHomeCity(_ value: String) {
        guard let profile = currentProfile() else { return }
        profile.homeCity = value
        profile.touch()
        trySave()
        homeCity = value
    }

    func setInterests(_ value: Set<TravelInterest>) {
        guard let profile = currentProfile() else { return }
        profile.interests = value.map(\.rawValue).joined(separator: ",")
        profile.touch()
        trySave()
        interests = value
    }

    func setTemperatureUnit(_ value: TemperatureUnit) {
        guard let profile = currentProfile() else { return }
        profile.tempUnit = value.rawValue
        profile.touch()
        trySave()
        temperatureUnit = value
    }

    func setRainTolerance(_ value: RainTolerance) {
        guard let profile = currentProfile() else { return }
        profile.rainTolerance = value.rawValue
        profile.touch()
        trySave()
        rainTolerance = value
    }

    func setDisplayName(_ value: String?) {
        guard let profile = currentProfile() else { return }
        profile.displayName = value
        profile.touch()
        trySave()
        displayName = value
    }

    func setEmail(_ value: String?) {
        guard let profile = currentProfile() else { return }
        profile.email = value
        profile.touch()
        trySave()
        email = value
    }

    func markLinked(email: String, displayName: String?) {
        guard let profile = currentProfile() else { return }
        profile.email = email
        profile.displayName = displayName
        profile.isAnonymous = false
        profile.touch()
        trySave()
        self.email = email
        self.displayName = displayName
        self.isAnonymous = false
    }

    func markAnonymous(uid: String) {
        // Called after sign-out hands a fresh anonymous UID.
        // Wipe old row(s) and start fresh
        wipeAllProfiles()
        do {
            try ensureProfile()
        } catch {
            // Best-effort:the row will be recreated on next launch
        }
    }


    func currentProfile() -> UserProfile? {
        let uid = Auth.auth().currentUser?.uid ?? ""
        return try? fetchProfile(uid: uid)
    }

    
    func ensureProfileRefresh() {
        loadCached()
    }

    
    
    private func fetchProfile(uid: String) throws -> UserProfile? {
        let request = UserProfile.fetchRequest()
        request.predicate = NSPredicate(format: "uid == %@", uid)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func loadCached() {
        guard let profile = try? fetchProfile(uid: Auth.auth().currentUser?.uid ?? "") else { return }
        refreshCache(from: profile)
    }

    private func refreshCache(from profile: UserProfile) {
        homeCity = profile.homeCity ?? ""
        let raw = profile.interests ?? ""
        interests = Set(raw.split(separator: ",").compactMap { TravelInterest(rawValue: String($0)) })
        temperatureUnit = TemperatureUnit(rawValue: profile.tempUnit ?? "celsius") ?? .celsius
        rainTolerance = RainTolerance(rawValue: profile.rainTolerance ?? "medium") ?? .medium
        email = profile.email
        displayName = profile.displayName
        isAnonymous = profile.isAnonymous
    }

    
    private func seedFromDefaults(_ profile: UserProfile) {
        let defaults = UserDefaults.standard
        if let city = defaults.string(forKey: PreferencesStore.Key.homeCity), !city.isEmpty {
            profile.homeCity = city
        }
        if let saved = defaults.stringArray(forKey: PreferencesStore.Key.interests), !saved.isEmpty {
            profile.interests = saved.joined(separator: ",")
        }
        if let unit = defaults.string(forKey: PreferencesStore.Key.temperatureUnit) {
            profile.tempUnit = unit
        }
        // rainTolerance has no legacy key — keep the default
    }

    private func wipeAllProfiles() {
        let request = UserProfile.fetchRequest()
        if let all = try? context.fetch(request) {
            for p in all { context.delete(p) }
        }
        trySave()
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func trySave() {
        try? save()
    }
}
