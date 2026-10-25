//
//  SettingsViewModel.swift
//  celon-compass
//
//  Orchestrates the Settings screen: refresh, guarded cache clearing, notification permission
//

internal import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    struct Notice: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
    }

    let preferences: PreferencesStore

    private(set) var cacheSize: Int64 = 0
    private(set) var lastSyncedAt: Date?
    private(set) var isRefreshing = false
    private(set) var isClearing = false

    var notice: Notice?
    var isShowingNotificationsDenied = false

    @ObservationIgnored private let cache: any CacheManaging
    @ObservationIgnored private let guardian: DestructiveActionGuard
    @ObservationIgnored private let refreshCatalog: () async throws -> Void
    @ObservationIgnored private let syncStatus: SyncStatusStore
    @ObservationIgnored private let notifications: any NotificationAuthorizing
    @ObservationIgnored private let now: () -> Date

    init(
        preferences: PreferencesStore? = nil,
        cache: any CacheManaging = CacheService(),
        guardian: DestructiveActionGuard? = nil,
        refreshCatalog: (() async throws -> Void)? = nil,
        syncStatus: SyncStatusStore? = nil,
        notifications: (any NotificationAuthorizing)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.preferences = preferences ?? PreferencesStore.shared
        self.cache = cache
        self.guardian = guardian ?? DestructiveActionGuard()
        self.refreshCatalog = refreshCatalog ?? { try await CatalogService().refreshFromRemote() }
        self.syncStatus = syncStatus ?? SyncStatusStore()
        self.notifications = notifications ?? SystemNotificationAuthorizer()
        self.now = now
        self.lastSyncedAt = self.syncStatus.lastSyncedAt
    }

    var biometry: BiometryKind { BiometricService.shared.biometryKind }

    var lastSyncedText: String { SyncStatusStore.displayString(for: lastSyncedAt) }

    var cacheSizeText: String {
        ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
    }

    var canClearCache: Bool { cacheSize > 0 && !isClearing }

    func load() async {
        lastSyncedAt = syncStatus.lastSyncedAt
        await reloadCacheSize()
    }

    func reloadCacheSize() async {
        cacheSize = await cache.totalSize()
    }

//refresh
    func refreshDestinations() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            try await refreshCatalog()
            let date = now()
            syncStatus.markSynced(at: date)
            lastSyncedAt = date
        } catch {
            notice = Notice(
                title: "Couldn't refresh",
                message: "Check your connection and try again."
            )
        }
    }

//clear cache
    func clearCache() async {
        guard !isClearing else { return }
        isClearing = true
        defer { isClearing = false }

        do {
     
            try await guardian.perform(reason: "Confirm clearing cached maps and photos") {
                try await cache.clear()
            }
            await reloadCacheSize()
            notice = Notice(
                title: "Cache cleared",
                message: "Offline maps and photos were removed. Your trips and memories are untouched."
            )
        } catch {
            if let message = DestructiveActionGuard.userMessage(for: error, noun: "the cache") {
                notice = Notice(title: "Cache not cleared", message: message)
            }
        }
    }

    //Notification preferences

    func setWeatherAlerts(_ enabled: Bool) async {
        await setNotificationPreference(enabled) { $0.weatherAlertsEnabled = $1 }
    }

    func setTripReminders(_ enabled: Bool) async {
        await setNotificationPreference(enabled) { $0.tripRemindersEnabled = $1 }
    }

    private func setNotificationPreference(
        _ enabled: Bool,
        apply: (PreferencesStore, Bool) -> Void
    ) async {
        apply(preferences, enabled)
        guard enabled else { return }

        let granted = await notifications.requestAuthorization()
        if !granted {
            apply(preferences, false)
            isShowingNotificationsDenied = true
        }
    }
}
