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
}
