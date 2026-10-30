//
//  ForgotPasswordView.swift
//  celon-compass
//

import SwiftUI

struct ForgotPasswordView: View {
    @Bindable var model: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppBrand.tealTop)

            Text("Reset your password")
                .font(.title2.bold())

            Text("Enter the email you used to create your account and we'll send you a link to reset your password.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Email", text: $model.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let error = model.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppBrand.destructive)
            }

            Button {
                Task { await model.sendResetEmail() }
            } label: {
                Group {
                    if model.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Send reset link")
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    model.isEmailValid ? AppBrand.tealTop : AppBrand.tealTop.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .disabled(!model.isEmailValid || model.isLoading)

            Button("Back to sign in") { model.screen = .signIn }
                .font(.subheadline)
                .foregroundStyle(AppBrand.link)

            Spacer()
        }
        .padding(20)
        .background(AppBrand.canvas)
    }
}
