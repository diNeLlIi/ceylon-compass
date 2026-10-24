//
//  DestructiveActionTests.swift
//  celon-compassTests
//
//  The core guarantee: a cancelled or failed second prompt never lets the delete run.
//

import Testing
import CoreData
@testable import celon_compass

@MainActor
struct DestructiveActionGuardTests {

    /// Runs the guard once and reports whether the action ran and what was thrown.
    private func attempt(_ result: BiometricResult) async -> (ran: Bool, error: Error?, stub: StubAuthenticator) {
        let stub = StubAuthenticator(result)
        let guardian = DestructiveActionGuard(authenticator: stub)
        var ran = false
        do {
            try await guardian.perform(reason: "test") { ran = true }
            return (ran, nil, stub)
        } catch {
            return (ran, error, stub)
        }
    }

    @Test func successRunsTheAction() async {
        let outcome = await attempt(.success)
        #expect(outcome.ran)
        #expect(outcome.error == nil)
    }

    @Test func cancelFailAndLockoutNeverRunTheAction() async {
        for result in [BiometricResult.cancelled, .failed, .lockedOut] {
            let outcome = await attempt(result)
            #expect(!outcome.ran, "action must not run for \(result)")
            #expect(outcome.error as? DestructiveActionGuard.GuardError == .notAuthorized(result))
        }
    }

    @Test func cancelIsReportedAsCancellation() async {
        let outcome = await attempt(.cancelled)
        let error = outcome.error as? DestructiveActionGuard.GuardError
        #expect(error?.isCancellation == true)
        #expect(DestructiveActionGuard.userMessage(for: error!, noun: "the trip") == nil)
    }

    @Test func failureProducesAMessage() async {
        let outcome = await attempt(.failed)
        #expect(DestructiveActionGuard.userMessage(for: outcome.error!, noun: "the trip") != nil)
    }

    @Test func noDeviceAuthenticationFallsBackToTheConfirmationDialog() async {
        let outcome = await attempt(.unavailable(.passcodeNotSet))
        #expect(outcome.ran)
    }

    @Test func requestsTheDestructivePurpose() async {
        let outcome = await attempt(.success)
        #expect(outcome.stub.purposes == [.destructiveAction])
    }

    @Test func actionErrorsPropagate() async {
        let guardian = DestructiveActionGuard(authenticator: StubAuthenticator(.success))
        do {
            try await guardian.perform(reason: "test") { throw TestError() }
            Issue.record("expected an error")
        } catch {
            #expect(error as? TestError == TestError())
        }
    }
}

@MainActor
@Suite(.serialized)
struct TripDeletionTests {

    @Test func deleteTripRemovesTripAndStopsAfterAuth() async throws {
        let trip = try TestStore.makeTrip(stopCount: 2)
        let repo = TripRepository(
            context: TestStore.context,
            guardian: DestructiveActionGuard(authenticator: StubAuthenticator(.success))
        )
        let id = trip.id!

        try await repo.deleteTrip(trip)

        #expect(try TestStore.count("Itinerary", where: "id == %@", id as CVarArg) == 0)
        #expect(try TestStore.count("ItineraryStop", where: "itinerary.id == %@", id as CVarArg) == 0)
    }

    @Test func cancellingThePromptKeepsTheTrip() async throws {
        let trip = try TestStore.makeTrip(stopCount: 2)
        let repo = TripRepository(
            context: TestStore.context,
            guardian: DestructiveActionGuard(authenticator: StubAuthenticator(.cancelled))
        )

        await #expect(throws: DestructiveActionGuard.GuardError.self) {
            try await repo.deleteTrip(trip)
        }

        #expect(!trip.isDeleted)
        #expect(!TestStore.context.hasChanges)
        #expect(try TestStore.tripCount(trip) == 1)
        #expect(try TestStore.stopCount(of: trip) == 2)
    }

    @Test func failedAuthKeepsTheTrip() async throws {
        let trip = try TestStore.makeTrip(stopCount: 1)
        let repo = TripRepository(
            context: TestStore.context,
            guardian: DestructiveActionGuard(authenticator: StubAuthenticator(.failed))
        )

        await #expect(throws: DestructiveActionGuard.GuardError.self) {
            try await repo.deleteTrip(trip)
        }

        #expect(try TestStore.tripCount(trip) == 1)
        #expect(try TestStore.stopCount(of: trip) == 1)
    }
}

@MainActor
@Suite(.serialized)
struct AccountDeletionTests {

    private final class Recorder {
        var remoteDeleteCalls = 0
        var afterDeletionCalls = 0
    }

    private func service(
        _ result: BiometricResult,
        recorder: Recorder,
        remoteFails: Bool = false
    ) -> AccountService {
        AccountService(
            context: TestStore.context,
            guardian: DestructiveActionGuard(authenticator: StubAuthenticator(result)),
            deleteRemoteAccount: {
                recorder.remoteDeleteCalls += 1
                if remoteFails { throw TestError() }
            },
            afterDeletion: { recorder.afterDeletionCalls += 1 }
        )
    }

    @Test func cancellingThePromptTouchesNothing() async throws {
        let trip = try TestStore.makeTrip()
        let recorder = Recorder()

        await #expect(throws: DestructiveActionGuard.GuardError.self) {
            try await service(.cancelled, recorder: recorder).deleteAccount()
        }

        #expect(recorder.remoteDeleteCalls == 0)
        #expect(recorder.afterDeletionCalls == 0)
        #expect(try TestStore.tripCount(trip) == 1)
    }

    @Test func remoteFailureLeavesLocalDataIntact() async throws {
        let trip = try TestStore.makeTrip()
        let recorder = Recorder()

        await #expect(throws: TestError.self) {
            try await service(.success, recorder: recorder, remoteFails: true).deleteAccount()
        }

        #expect(recorder.remoteDeleteCalls == 1)
        #expect(recorder.afterDeletionCalls == 0)
        #expect(try TestStore.tripCount(trip) == 1)
        #expect(try TestStore.stopCount(of: trip) == 2)
    }

    @Test func successDeletesRemoteThenWipesLocalData() async throws {
        let trip = try TestStore.makeTrip()
        let destination = Destination(context: TestStore.context)
        destination.id = UUID()
        destination.isFavourite = true
        try TestStore.context.save()
        let recorder = Recorder()

        try await service(.success, recorder: recorder).deleteAccount()

        #expect(recorder.remoteDeleteCalls == 1)
        #expect(recorder.afterDeletionCalls == 1)
        #expect(try TestStore.tripCount(trip) == 0)
        #expect(destination.isFavourite == false)
    }
}
