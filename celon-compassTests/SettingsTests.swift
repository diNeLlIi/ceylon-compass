//
//  SettingsTests.swift
//  celon-compassTests
//
//  Cache service, preferences, sync status, and the guarded Clear Cache flow
//

import Testing
import Foundation
@testable import celon_compass

//fake cache
nonisolated final class FakeCache: CacheManaging, @unchecked Sendable {
    private let lock = NSLock()
    private var size: Int64
    private(set) var clearCount = 0
    var failure: Error?

    init(size: Int64) { self.size = size }

    func totalSize() async -> Int64 { lock.withLock { size } }

    func clear() async throws {
        try lock.withLock {
            clearCount += 1
            if let failure { throw failure }
            size = 0
        }
    }
}

@MainActor
final class FakeNotifier: NotificationAuthorizing {
    var granted: Bool
    private(set) var requestCount = 0
    init(granted: Bool) { self.granted = granted }

    func requestAuthorization() async -> Bool {
        requestCount += 1
        return granted
    }
}

@MainActor
private func makeDefaults() -> UserDefaults {
    let suite = "settings-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}


//cache service
struct CacheServiceTests {
    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(bytes: Int, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
    }

    @Test func emptyOrMissingFoldersAreZeroBytes() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString)")
        let service = CacheService(directories: [missing], includesURLCache: false)
        #expect(await service.totalSize() == 0)
    }

    @Test func sizeIncludesNestedFiles() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try write(bytes: 10_000, to: root.appendingPathComponent("a.bin"))
        try write(bytes: 20_000, to: root.appendingPathComponent("nested/deep/b.bin"))

        let service = CacheService(directories: [root], includesURLCache: false)
        // Allocated size is rounded up to disk blocks, so it is at least the raw size.
        #expect(await service.totalSize() >= 30_000)
    }

    @Test func clearEmptiesFoldersButKeepsThem() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try write(bytes: 5_000, to: root.appendingPathComponent("a.bin"))
        try write(bytes: 5_000, to: root.appendingPathComponent("nested/b.bin"))

        let service = CacheService(directories: [root], includesURLCache: false)
        try await service.clear()

        #expect(await service.totalSize() == 0)
        #expect(FileManager.default.fileExists(atPath: root.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test func clearLeavesUnrelatedFoldersAlone() async throws {
        let cache = try makeTempDirectory()
        let other = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: cache)
            try? FileManager.default.removeItem(at: other)
        }
        try write(bytes: 1_000, to: cache.appendingPathComponent("a.bin"))
        let keep = other.appendingPathComponent("keep.bin")
        try write(bytes: 1_000, to: keep)

        try await CacheService(directories: [cache], includesURLCache: false).clear()
        #expect(FileManager.default.fileExists(atPath: keep.path))
    }

    @Test func clearingMissingFoldersDoesNotThrow() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString)")
        try await CacheService(directories: [missing], includesURLCache: false).clear()
    }
}


//preferences
@MainActor
struct PreferencesStoreTests {
    @Test func defaults() {
        let store = PreferencesStore(defaults: makeDefaults())
        #expect(store.temperatureUnit == .celsius)
        #expect(!store.weatherAlertsEnabled)
        #expect(!store.tripRemindersEnabled)
    }

    @Test func valuesPersistAcrossInstances() {
        let defaults = makeDefaults()
        let first = PreferencesStore(defaults: defaults)
        first.temperatureUnit = .fahrenheit
        first.weatherAlertsEnabled = true
        first.tripRemindersEnabled = true

        let second = PreferencesStore(defaults: defaults)
        #expect(second.temperatureUnit == .fahrenheit)
        #expect(second.weatherAlertsEnabled)
        #expect(second.tripRemindersEnabled)
    }

    @Test func unknownStoredUnitFallsBackToCelsius() {
        let defaults = makeDefaults()
        defaults.set("kelvin", forKey: PreferencesStore.Key.temperatureUnit)
        #expect(PreferencesStore(defaults: defaults).temperatureUnit == .celsius)
    }
}


//syncstatus
@MainActor
struct SyncStatusTests {
    private let locale = Locale(identifier: "en_US")

    @Test func neverWhenUnset() {
        #expect(SyncStatusStore(defaults: makeDefaults()).lastSyncedAt == nil)
        #expect(SyncStatusStore.displayString(for: nil) == "Never")
    }

    @Test func markSyncedPersists() {
        let defaults = makeDefaults()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        SyncStatusStore(defaults: defaults).markSynced(at: date)
        #expect(SyncStatusStore(defaults: defaults).lastSyncedAt == date)
    }

    @Test func todayIsShownRelatively() {
        let text = SyncStatusStore.displayString(for: Date(), locale: locale)
        #expect(text.hasPrefix("Today"))
    }

    @Test func olderDatesAreNotShownAsToday() {
        let old = Date().addingTimeInterval(-10 * 24 * 3600)
        #expect(!SyncStatusStore.displayString(for: old, locale: locale).hasPrefix("Today"))
    }
}




@MainActor
struct SettingsViewModelTests {
    private func makeModel(
        cache: FakeCache? = nil,
        auth: StubAuthenticator? = nil,
        refresh: @escaping () async throws -> Void = {},
        notifier: FakeNotifier? = nil,
        defaults: UserDefaults? = nil,
        now: @escaping () -> Date = Date.init
    ) -> SettingsViewModel {
        let defaults = defaults ?? makeDefaults()
        return SettingsViewModel(
            preferences: PreferencesStore(defaults: defaults),
            cache: cache ?? FakeCache(size: 148_000_000),
            guardian: DestructiveActionGuard(authenticator: auth ?? StubAuthenticator(.success)),
            refreshCatalog: refresh,
            syncStatus: SyncStatusStore(defaults: defaults),
            notifications: notifier ?? FakeNotifier(granted: true),
            now: now
        )
    }

    // Clear cache

    @Test func clearCacheSucceedsAfterAuthentication() async {
        let cache = FakeCache(size: 1_000)
        let auth = StubAuthenticator(.success)
        let model = makeModel(cache: cache, auth: auth)
        await model.load()
        #expect(model.cacheSize == 1_000)

        await model.clearCache()

        #expect(cache.clearCount == 1)
        #expect(model.cacheSize == 0)
        #expect(model.notice?.title == "Cache cleared")
        #expect(auth.purposes == [.destructiveAction])
    }

    @Test func cancelledPromptClearsNothingAndStaysSilent() async {
        let cache = FakeCache(size: 1_000)
        let model = makeModel(cache: cache, auth: StubAuthenticator(.cancelled))
        await model.load()

        await model.clearCache()

        #expect(cache.clearCount == 0)
        #expect(model.cacheSize == 1_000)
        #expect(model.notice == nil)
    }

    @Test func failedAndLockedOutPromptsClearNothingAndExplain() async {
        for result in [BiometricResult.failed, .lockedOut] {
            let cache = FakeCache(size: 1_000)
            let model = makeModel(cache: cache, auth: StubAuthenticator(result))
            await model.load()

            await model.clearCache()

            #expect(cache.clearCount == 0, "cache must stay for \(result)")
            #expect(model.notice?.title == "Cache not cleared")
        }
    }

    @Test func noDeviceAuthenticationFallsBackToTheConfirmationDialog() async {
        let cache = FakeCache(size: 1_000)
        let model = makeModel(cache: cache, auth: StubAuthenticator(.unavailable(.passcodeNotSet)))
        await model.load()
        await model.clearCache()
        #expect(cache.clearCount == 1)
    }

    @Test func cacheFailureIsReportedAndSizeKept() async {
        let cache = FakeCache(size: 1_000)
        cache.failure = TestError()
        let model = makeModel(cache: cache)
        await model.load()

        await model.clearCache()

        #expect(model.notice?.title == "Cache not cleared")
        #expect(model.cacheSize == 1_000)
    }

    @Test func emptyCacheCannotBeCleared() async {
        let model = makeModel(cache: FakeCache(size: 0))
        await model.load()
        #expect(!model.canClearCache)
    }

    // Refresh

    @Test func successfulRefreshStampsTheDate() async {
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let model = makeModel(now: { stamp })
        #expect(model.lastSyncedAt == nil)

        await model.refreshDestinations()

        #expect(model.lastSyncedAt == stamp)
        #expect(model.notice == nil)
    }

    @Test func failedRefreshKeepsThePreviousDate() async {
        let defaults = makeDefaults()
        let previous = Date(timeIntervalSince1970: 1_600_000_000)
        SyncStatusStore(defaults: defaults).markSynced(at: previous)
        let model = makeModel(refresh: { throw TestError() }, defaults: defaults)

        await model.refreshDestinations()

        #expect(model.lastSyncedAt == previous)
        #expect(model.notice?.title == "Couldn't refresh")
    }

    // Notification toggles

    @Test func enablingWithPermissionSticks() async {
        let notifier = FakeNotifier(granted: true)
        let model = makeModel(notifier: notifier)

        await model.setWeatherAlerts(true)

        #expect(model.preferences.weatherAlertsEnabled)
        #expect(!model.isShowingNotificationsDenied)
        #expect(notifier.requestCount == 1)
    }

    @Test func enablingWithoutPermissionRevertsAndPrompts() async {
        let model = makeModel(notifier: FakeNotifier(granted: false))

        await model.setTripReminders(true)

        #expect(!model.preferences.tripRemindersEnabled)
        #expect(model.isShowingNotificationsDenied)
    }

    @Test func disablingNeverAsksForPermission() async {
        let notifier = FakeNotifier(granted: true)
        let model = makeModel(notifier: notifier)
        await model.setWeatherAlerts(true)

        await model.setWeatherAlerts(false)

        #expect(!model.preferences.weatherAlertsEnabled)
        #expect(notifier.requestCount == 1)
    }
}
