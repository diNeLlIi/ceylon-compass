//
//  BiometricService.swift
//  celon-compass
//
//  Created by student2 on 2026-10-23.
//

import LocalAuthentication

final class BiometricService {
    static let shared = BiometricService()
    private init() {}

    enum AuthResult {
        case success
        case failure(String)
    }

    func authenticate(reason: String) async -> AuthResult {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .failure(error?.localizedDescription ?? "Authentication is not available on this device.")
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return success ? .success : .failure("Authentication failed.")
        } catch let authError as LAError {
            return .failure(authError.localizedDescription)
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
