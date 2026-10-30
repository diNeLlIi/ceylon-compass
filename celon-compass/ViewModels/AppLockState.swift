//
//  AppLockState.swift
//  celon-compass
//
//  Created by student2 on 2026-10-23.
//

import SwiftUI

@MainActor
@Observable
final class AppLockState {
    enum LockReason: Equatable {
        case none
        case cancelled
        case failed
        case lockedOut
    }

    private(set) var isLocked = PreferencesStore.shared.faceIDLockEnabled
    // Protected content is only mounted after the first successful unlock.
    private(set) var hasUnlockedOnce = !PreferencesStore.shared.faceIDLockEnabled
    private(set) var isAuthenticating = false
    private(set) var reason: LockReason = .none
    private(set) var failureCount = 0
    private(set) var notice: String?

    private let authenticator: any BiometricAuthenticating
    private var lockGeneration = 0

    var biometry: BiometryKind { authenticator.biometryKind }

    init(authenticator: any BiometricAuthenticating = BiometricService.shared) {
        self.authenticator = authenticator
    }

    func authenticateIfNeeded() async {
        guard isLocked, reason == .none else { return }
        await authenticate()
    }

    func authenticate() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        let generation = lockGeneration

        let result = await authenticator.authenticate(
            reason: "Unlock \(AppBrand.name)",
            purpose: .launchGate
        )

        isAuthenticating = false
        guard generation == lockGeneration else { return }
        apply(result)
    }

    // Finishing onboarding counts as the first unlock. With the lock now defaulting to on,
    // the gate would otherwise appear the instant the user finished setting the app up —
    // a prompt to prove they are themselves, seconds after they chose their preferences.
    // Backgrounding the app still locks it, so this only skips that one gate.
    func skipGateAfterOnboarding() {
        lockGeneration += 1
        isAuthenticating = false
        unlock(notice: nil)
    }

    func lock() {
        guard PreferencesStore.shared.faceIDLockEnabled else { return }
        lockGeneration += 1
        isLocked = true
        reason = .none
        notice = nil
    }

    private func apply(_ result: BiometricResult) {
        switch result {
        case .success:
            unlock(notice: nil)
        case .unavailable:
            unlock(notice: "Your device passcode is off. Turn one on in Settings to protect \(AppBrand.name).")
        case .cancelled:
            reason = .cancelled
        case .failed:
            reason = .failed
            failureCount += 1
        case .lockedOut:
            reason = .lockedOut
        }
    }

    private func unlock(notice: String?) {
        self.notice = notice
        reason = .none
        hasUnlockedOnce = true
        isLocked = false
    }
}
