//
//  BiometricService.swift
//  celon-compass
//
//  Created by student2 on 2026-10-23.
//

import LocalAuthentication

enum AuthPurpose {
    case launchGate
    case destructiveAction
}

enum UnavailableReason: Equatable {
    case passcodeNotSet
    case notAvailable
}

enum BiometricResult: Equatable {
    case success
    case cancelled
    case failed
    case lockedOut
    case unavailable(UnavailableReason)
}

enum BiometryKind {
    case faceID
    case touchID
    case opticID
    case noBiometry

    var title: String {
        switch self {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        case .noBiometry: "Passcode"
        }
    }

    var symbolName: String {
        switch self {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .noBiometry: "lock.fill"
        }
    }

    func prompt(appName: String) -> String {
        switch self {
        case .faceID: "Look at your iPhone to unlock \(appName)"
        case .touchID: "Use your fingerprint to unlock \(appName)"
        case .opticID: "Look at the display to unlock \(appName)"
        case .noBiometry: "Enter your passcode to unlock \(appName)"
        }
    }
}

protocol BiometricAuthenticating {
    var biometryKind: BiometryKind { get }
    func authenticate(reason: String, purpose: AuthPurpose) async -> BiometricResult
}

final class BiometricService: BiometricAuthenticating {
    static let shared = BiometricService()
    private init() {}

    var biometryKind: BiometryKind {
        let context = LAContext()
        var error: NSError?
        // biometryType is only populated after canEvaluatePolicy has been called.
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .noBiometry
        }
    }


    func authenticate(reason: String, purpose: AuthPurpose) async -> BiometricResult {
        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = 0

        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            return Self.map(policyError)
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return success ? .success : .failed
        } catch {
            return Self.map(error)
        }
    }

    private static func map(_ error: Error?) -> BiometricResult {
        guard let laError = error as? LAError else { return .failed }
        switch laError.code {
        case .userCancel, .appCancel, .systemCancel, .userFallback:
            return .cancelled
        case .authenticationFailed:
            return .failed
        case .biometryLockout:
            return .lockedOut
        case .passcodeNotSet:
            return .unavailable(.passcodeNotSet)
        case .biometryNotAvailable, .biometryNotEnrolled:
            return .unavailable(.notAvailable)
        default:
            return .failed
        }
    }
}
