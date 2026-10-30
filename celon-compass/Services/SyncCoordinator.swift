//
//  SyncCoordinator.swift
//  celon-compass
//
//

import Foundation

@MainActor
@Observable
final class SyncCoordinator {
    static let shared = SyncCoordinator()

    enum SyncState: Equatable {
        case idle
        case syncing
        case synced(Date)
        case offline(pending: Int)
        case failed
        case guest
    }

    private(set) var state: SyncState = .guest

    @ObservationIgnored private let service: any SyncServicing
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private let debounceInterval: TimeInterval

    init(
        service: any SyncServicing = SyncService(),
        debounceInterval: TimeInterval = 1.5
    ) {
        self.service = service
        self.debounceInterval = debounceInterval
    }

    ///Called by any writer after a Core Data save. Debounced — many calls
    // within 1.5s coalesce into a single push.
    func enqueue() {
        guard !AuthService.shared.isAnonymous else {
            state = .guest
            return
        }
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(debounceInterval))
            guard !Task.isCancelled else { return }
            await push()
        }
    }

    func pushNow() async {
        guard !AuthService.shared.isAnonymous else {
            state = .guest
            return
        }
        debounceTask?.cancel()
        await push()
    }

    // Pull all remote data (called on first sign-in for a UID)
    func pullIfNeeded() async {
        guard !AuthService.shared.isAnonymous else { return }
        do {
            try await service.pullAll()
        } catch {
            // Pull failures are non-fatal:local data is still usable
        }
    }

    private func push() async {
        state = .syncing
        do {
            try await service.pushPending()
            state = .synced(Date())
        } catch {
            state = .failed
        }
    }
}
