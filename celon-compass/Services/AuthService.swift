//
//  AuthService.swift
//  celon-compass
//
//  Created by student2 on 2026-10-23.
//

import FirebaseAuth

final class AuthService {
    static let shared = AuthService()
    private init() {}

    func signInAnonymouslyIfNeeded() async throws {
        if Auth.auth().currentUser == nil {
            try await Auth.auth().signInAnonymously()
        }
    }

    // Email of the signed-in user, or nil for the anonymous guest identity.
    var linkedEmail: String? {
        guard let user = Auth.auth().currentUser, !user.isAnonymous else { return nil }
        return user.email
    }
}
