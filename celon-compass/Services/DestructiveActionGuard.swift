//
//  DestructiveActionGuard.swift
//  celon-compass
//
//  Gate for irreversible actions:cancelled or failed prompt never fall through to a delete
//

import Foundation

@MainActor
struct DestructiveActionGuard {
    enum GuardError: Error, Equatable {
        case notAuthorized(BiometricResult)

        var isCancellation: Bool {
            if case .notAuthorized(.cancelled) = self { return true }
            return false
        }
    }

    private let authenticator: any BiometricAuthenticating

    init(authenticator: (any BiometricAuthenticating)? = nil) {
        self.authenticator = authenticator ?? BiometricService.shared
    }

    
    
    //re-authenticates before action
    func perform(reason: String, action: () async throws -> Void) async throws {
        let result = await authenticator.authenticate(reason: reason, purpose: .destructiveAction)
        switch result {
        case .success:
            break
        case .unavailable:
            break
        case .cancelled, .failed, .lockedOut:
            throw GuardError.notAuthorized(result)
        }
        try await action()
    }

    // User-facing text for a failed destructive action, or nil if the user simply cancelled.
    static func userMessage(for error: Error, noun: String) -> String? {
        if let guardError = error as? GuardError {
            return guardError.isCancellation
                ? nil
                : "We couldn't verify it's you, so \(noun) was not deleted."
        }
        return error.localizedDescription
    }
}
