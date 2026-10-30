//
//  AuthViewModel.swift
//  celon-compass
//
//  Drives the auth screens: create account, sign in, forgot password.
//  Validation is pure computed — testable without Firebase
//

import FirebaseAuth
import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    
//Fields

    var email = ""
    var password = ""
    var displayName = ""
    var isPasswordVisible = false

    enum Screen: Hashable {
        case createAccount
        case signIn
        case forgotPassword
        case checkEmail(String)
    }

    var screen: Screen = .createAccount
    var isLoading = false
    var error: String?
    var resendCountdown = 0

    private let auth: AuthService
    @ObservationIgnored private var resendTimer: Timer?

    init(auth: AuthService = .shared) {
        self.auth = auth
    }

    
    //Validation (pure, testable)

    var isEmailValid: Bool {
        let pattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
        return email.wholeMatch(of: pattern) != nil
    }

    var isPasswordValid: Bool {
        password.count >= 6
    }

    var passwordStrength: PasswordStrength {
        let length = password.count
        if length < 6 { return .tooShort }
        if length < 8 { return .weak }
        let hasUpper = password.contains(where: \.isUppercase)
        let hasDigit = password.contains(where: \.isNumber)
        let hasSpecial = password.contains(where: { !$0.isLetter && !$0.isNumber })
        let score = [hasUpper, hasDigit, hasSpecial].filter { $0 }.count
        if length >= 12 && score >= 2 { return .strong }
        if score >= 1 { return .fair }
        return .weak
    }

    var canSubmitCreate: Bool { isEmailValid && isPasswordValid }
    var canSubmitSignIn: Bool { isEmailValid && !password.isEmpty }

    
    //actions

    func createAccount() async {
        guard canSubmitCreate else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let user = try await auth.register(
                email: email,
                password: password,
                displayName: displayName.isEmpty ? nil : displayName
            )
            UserProfileStore.shared.markLinked(
                email: email,
                displayName: displayName.isEmpty ? nil : displayName
            )
            
            await SyncCoordinator.shared.pushNow()
            await SyncCoordinator.shared.pullIfNeeded()
        } catch let failure as AuthFailure {
            error = failure.userMessage
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signIn() async {
        guard canSubmitSignIn else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let user = try await auth.signIn(email: email, password: password)
            // Refresh profile from the signed-in user
            try? UserProfileStore.shared.ensureProfile()
            await SyncCoordinator.shared.pullIfNeeded()
            await SyncCoordinator.shared.pushNow()
        } catch let failure as AuthFailure {
            error = failure.userMessage
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendResetEmail() async {
        guard isEmailValid else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await auth.sendPasswordReset(email: email)
            screen = .checkEmail(email)
            startResendCountdown()
        } catch let failure as AuthFailure {
            error = failure.userMessage
        } catch {
            self.error = error.localizedDescription
        }
    }

    func resend() async {
        guard resendCountdown == 0 else { return }
        do {
            try await auth.sendPasswordReset(email: email)
            startResendCountdown()
        } catch {
            // Silently fail resend
        }
    }

    func signOut() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.signOut()
            UserProfileStore.shared.markAnonymous(uid: auth.currentUID ?? "")
        } catch {
            self.error = "Couldn't sign out. Please try again."
        }
    }

    private func startResendCountdown() {
        resendCountdown = 30
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self else { timer.invalidate(); return }
                self.resendCountdown -= 1
                if self.resendCountdown <= 0 { timer.invalidate() }
            }
        }
    }
}

//password strength
enum PasswordStrength {
    case tooShort, weak, fair, strong

    var label: String {
        switch self {
        case .tooShort: "Too short"
        case .weak: "Weak"
        case .fair: "Fair"
        case .strong: "Strong"
        }
    }

    var fraction: Double {
        switch self {
        case .tooShort: 0.15
        case .weak: 0.35
        case .fair: 0.65
        case .strong: 1.0
        }
    }
}
