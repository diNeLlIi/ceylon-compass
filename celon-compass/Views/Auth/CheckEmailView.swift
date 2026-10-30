//
//  CheckEmailView.swift
//  celon-compass
//

import SwiftUI

struct CheckEmailView: View {
    @Bindable var model: AuthViewModel
    let email: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppBrand.success)

            Text("Check your email")
                .font(.title2.bold())

            Text("We sent a reset link to **\(email)**")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if UIApplication.shared.canOpenURL(URL(string: "message://")!) {
                Button {
                    openURL(URL(string: "message://")!)
                } label: {
                    Text("Open Mail")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppBrand.tealTop, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            Button("Back to sign in") { model.screen = .signIn }
                .font(.subheadline)
                .foregroundStyle(AppBrand.link)

            Button {
                Task { await model.resend() }
            } label: {
                if model.resendCountdown > 0 {
                    Text("Resend in 0:\(String(format: "%02d", model.resendCountdown))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Didn't get it? Resend")
                        .font(.caption)
                        .foregroundStyle(AppBrand.link)
                }
            }
            .disabled(model.resendCountdown > 0)

            Spacer()
        }
        .padding(20)
        .background(AppBrand.canvas)
    }
}
