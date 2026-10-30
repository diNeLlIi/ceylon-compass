//
//  AuthService.swift
//  celon-compass
//
//  Created by student2 on 2026-10-23.
//Firebase Auth: anonymous bootstrap, email/password linking, sign in/out, delete
//

import FirebaseAuth
import Foundation


//Error mapping

enum AuthFailure: Error, Equatable {
    case emailInUse, weakPassword, invalidEmail, wrongPassword
    case userNotFound, network, requiresRecentLogin
    case unknown(String)

    static func map(_ error: Error) -> AuthFailure {
        let nsError = error as NSError
        switch AuthErrorCode(rawValue: nsError.code) {
        case .credentialAlreadyInUse, .emailAlreadyInUse: return .emailInUse
        case .weakPassword:                               return .weakPassword
        case .invalidEmail:                               return .invalidEmail
        case .wrongPassword, .invalidCredential:          return .wrongPassword
        case .userNotFound:                               return .userNotFound
        case .networkError:                               return .network
        case .requiresRecentLogin:                        return .requiresRecentLogin
        default:                                          return .unknown(nsError.localizedDescription)
        }
    }

    var userMessage: String {
        switch self {
        case .emailInUse:          "That email is already linked to another account."
        case .weakPassword:        "Password must be at least 6 characters."
        case .invalidEmail:        "That doesn't look like a valid email address."
        case .wrongPassword:       "Incorrect password. Try again."
        case .userNotFound:        "No account found for that email."
        case .network:             "No connection — check your network and try again."
        case .requiresRecentLogin: "For security, please sign in again before continuing."
        case .unknown(let msg):    msg
        }
    }
}


//AuthService

final class AuthService: Sendable {
    static let shared = AuthService()
    private init() {}

    // Ensures a Firebase session exists. Called on every launch
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

    var isAnonymous: Bool {
        Auth.auth().currentUser?.isAnonymous ?? true
    }

    var currentUID: String? {
        Auth.auth().currentUser?.uid
    }

    
    //Registration (link path)

    // Links an email/password credential onto the current anonymous session,
    // preserving the UID and all local data keyed to it
    @discardableResult
    func register(email: String, password: String, displayName: String?) async throws -> User {
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        let user: User
        do {
            if let current = Auth.auth().currentUser, current.isAnonymous {
                user = try await current.link(with: credential).user
            } else {
                user = try await Auth.auth().createUser(withEmail: email, password: password).user
            }
        } catch {
            throw AuthFailure.map(error)
        }

        if let displayName, !displayName.isEmpty {
            let change = user.createProfileChangeRequest()
            change.displayName = displayName
            try? await change.commitChanges()
        }
        return user
    }

    
    
    //Sign in / out

    func signIn(email: String, password: String) async throws -> User {
        do {
            return try await Auth.auth().signIn(withEmail: email, password: password).user
        } catch {
            throw AuthFailure.map(error)
        }
    }

 
    func signOut() async throws {
        try Auth.auth().signOut()
        try await Auth.auth().signInAnonymously()
    }

    
    //Password reset

    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            let mapped = AuthFailure.map(error)
            if mapped != .userNotFound { throw mapped }
        }
    }
    
    
    //Re-authentication (required before destructive ops on stale sessions)

    func reauthenticate(password: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw AuthFailure.userNotFound
        }
        do {
            try await user.reauthenticate(
                with: EmailAuthProvider.credential(withEmail: email, password: password)
            )
        } catch {
            throw AuthFailure.map(error)
        }
    }

    
    //Delete auth user
    func deleteAuthUser() async throws {
        do {
            try await Auth.auth().currentUser?.delete()
        } catch {
            throw AuthFailure.map(error)
        }
    }
}
