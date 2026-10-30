//
//  CreateAccountView.swift
//  celon-compass
//

import SwiftUI

struct CreateAccountView: View {
    @Bindable var model: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                fields
                createButton
                links
            }
            .padding(20)
        }
        .background(AppBrand.canvas)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(AppBrand.tealTop)
            Text("Create your account")
                .font(.title2.bold())
            Text("Sync your trips across devices")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    private var fields: some View {
        VStack(spacing: 14) {
            TextField("Display name (optional)", text: $model.displayName)
                .textContentType(.name)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            TextField("Email", text: $model.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            PasswordField(
                placeholder: "Password (6+ characters)",
                text: $model.password,
                isVisible: $model.isPasswordVisible,
                strength: model.password.isEmpty ? nil : model.passwordStrength
            )

            if let error = model.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppBrand.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var createButton: some View {
        Button {
            Task {
                await model.createAccount()
                if model.error == nil { dismiss() }
            }
        } label: {
            Group {
                if model.isLoading {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Creating account…")
                    }
                } else {
                    Text("Create account")
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                model.canSubmitCreate ? AppBrand.tealTop : AppBrand.tealTop.opacity(0.4),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .disabled(!model.canSubmitCreate || model.isLoading)
    }

    private var links: some View {
        VStack(spacing: 12) {
            Button("Already have an account? Sign in") {
                model.screen = .signIn
            }
            .font(.subheadline)
            .foregroundStyle(AppBrand.link)

            Button("Continue as guest (no sync)") {
                dismiss()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
