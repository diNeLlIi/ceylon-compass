//
//  SignInView.swift
//  celon-compass
//

import SwiftUI

struct SignInView: View {
    @Bindable var model: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                fields
                signInButton
                links
            }
            .padding(20)
        }
        .background(AppBrand.canvas)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 48))
                .foregroundStyle(AppBrand.tealTop)
            Text("Welcome back")
                .font(.title2.bold())
        }
        .padding(.top, 20)
    }

    private var fields: some View {
        VStack(spacing: 14) {
            TextField("Email", text: $model.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            PasswordField(
                placeholder: "Password",
                text: $model.password,
                isVisible: $model.isPasswordVisible
            )

            if let error = model.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppBrand.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var signInButton: some View {
        Button {
            Task {
                await model.signIn()
                if model.error == nil { dismiss() }
            }
        } label: {
            Group {
                if model.isLoading {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Signing in…")
                    }
                } else {
                    Text("Sign in")
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                model.canSubmitSignIn ? AppBrand.tealTop : AppBrand.tealTop.opacity(0.4),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .disabled(!model.canSubmitSignIn || model.isLoading)
    }

    private var links: some View {
        VStack(spacing: 12) {
            Button("Forgot password?") {
                model.screen = .forgotPassword
            }
            .font(.subheadline)
            .foregroundStyle(AppBrand.link)

            Button("New to \(AppBrand.name)? Create an account") {
                model.screen = .createAccount
            }
            .font(.subheadline)
            .foregroundStyle(AppBrand.link)
        }
    }
}
