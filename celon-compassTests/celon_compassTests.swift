//
//  celon_compassTests.swift
//  celon-compassTests
//
//  Launch-gate behaviour (AppLockState). Face ID itself can't be driven from unit
//  tests, so these use a scripted authenticator.
//

import Testing
@testable import celon_compass

@MainActor
struct AppLockStateTests {

    @Test func startsLocked() {
        let state = AppLockState(authenticator: StubAuthenticator(.success))
        #expect(state.isLocked)
        #expect(!state.hasUnlockedOnce)
    }

    @Test func successUnlocks() async {
        let state = AppLockState(authenticator: StubAuthenticator(.success))
        await state.authenticate()
        #expect(!state.isLocked)
        #expect(state.hasUnlockedOnce)
        #expect(state.notice == nil)
    }

    @Test func cancelStaysLocked() async {
        let state = AppLockState(authenticator: StubAuthenticator(.cancelled))
        await state.authenticate()
        #expect(state.isLocked)
        #expect(state.reason == .cancelled)
        #expect(!state.hasUnlockedOnce)
    }

    @Test func nonMatchingFaceStaysLockedAndAllowsRetry() async {
        let stub = StubAuthenticator(.failed, .success)
        let state = AppLockState(authenticator: stub)

        await state.authenticate()
        #expect(state.isLocked)
        #expect(state.reason == .failed)
        #expect(state.failureCount == 1)

        // Retry (button tap) succeeds.
        await state.authenticate()
        #expect(!state.isLocked)
        #expect(stub.callCount == 2)
    }

    @Test func lockoutStaysLocked() async {
        let state = AppLockState(authenticator: StubAuthenticator(.lockedOut))
        await state.authenticate()
        #expect(state.isLocked)
        #expect(state.reason == .lockedOut)
    }

    @Test func noDeviceAuthenticationUnlocksWithNotice() async {
        let state = AppLockState(authenticator: StubAuthenticator(.unavailable(.passcodeNotSet)))
        await state.authenticate()
        #expect(!state.isLocked)
        #expect(state.notice != nil)
    }

    @Test func automaticPromptDoesNotLoopAfterCancel() async {
        let stub = StubAuthenticator(.cancelled)
        let state = AppLockState(authenticator: stub)

        await state.authenticateIfNeeded()
        await state.authenticateIfNeeded()
        await state.authenticateIfNeeded()

        #expect(stub.callCount == 1)
    }

    @Test func relockResetsStateAndPromptsAgain() async {
        let stub = StubAuthenticator(.success)
        let state = AppLockState(authenticator: stub)

        await state.authenticate()
        #expect(!state.isLocked)

        state.lock()
        #expect(state.isLocked)
        #expect(state.reason == .none)

        await state.authenticateIfNeeded()
        #expect(!state.isLocked)
        #expect(stub.callCount == 2)
    }

    @Test func concurrentRequestsProduceOnePrompt() async {
        let stub = StubAuthenticator(.success, delay: .milliseconds(100))
        let state = AppLockState(authenticator: stub)

        async let first: Void = state.authenticate()
        async let second: Void = state.authenticate()
        _ = await (first, second)

        #expect(stub.callCount == 1)
    }

    @Test func staleResultCannotUnlockANewerLock() async throws {
        let stub = StubAuthenticator(.success, delay: .milliseconds(150))
        let state = AppLockState(authenticator: stub)

        let inFlight = Task { await state.authenticate() }
        try await Task.sleep(for: .milliseconds(30))
        state.lock()   // app went to background while the prompt was up
        await inFlight.value

        #expect(state.isLocked)
        #expect(!state.hasUnlockedOnce)
    }
}
