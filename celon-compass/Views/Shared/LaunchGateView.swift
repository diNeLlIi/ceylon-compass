//
//  LaunchGateView.swift
//  celon-compass
//
//  Created by student2 on 2026-10-23.
//

import SwiftUI

struct LaunchGateView: View {
    var lockState: AppLockState
    var autoPrompt: Bool = true

    @Environment(\.scenePhase) private var scenePhase
    @State private var appeared = false

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(spacing: 0) {
                Spacer()
                header
                Spacer()
                controls
            }
            .padding(.bottom, 28)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appeared = true }
        }
        
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard autoPrompt, phase == .active else { return }
            Task { await lockState.authenticateIfNeeded() }
        }
        .sensoryFeedback(.error, trigger: lockState.failureCount)
    }

    private var header: some View {
        VStack(spacing: 18) {
            CompassMark(size: 96)

            Text(AppBrand.name)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(AppBrand.tagline)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        let biometry = lockState.biometry

        return VStack(spacing: 10) {
            Button {
                Task { await lockState.authenticate() }
            } label: {
                Image(systemName: biometry.symbolName)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: lockState.isAuthenticating)
                    .frame(width: 76, height: 76)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.white.opacity(0.16))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.22), lineWidth: 1)
                    )
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Unlock with \(biometry.title)")
            .accessibilityIdentifier("unlock.biometric")

            Text(biometry.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Text(statusMessage)
                .font(.system(size: 13))
                .foregroundStyle(isErrorState ? AppBrand.amber : .white.opacity(0.72))
                .multilineTextAlignment(.center)
                .frame(minHeight: 36, alignment: .top)
                .padding(.horizontal, 40)
                .animation(.easeInOut(duration: 0.2), value: lockState.reason)
                .accessibilityIdentifier("unlock.status")

           
            Button {
                Task { await lockState.authenticate() }
            } label: {
                Text("Use Passcode")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 172, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("unlock.passcode")
        }
    }

    private var isErrorState: Bool {
        lockState.reason != .none
    }

    private var statusMessage: String {
        let biometry = lockState.biometry
        switch lockState.reason {
        case .none:
            return lockState.isAuthenticating
                ? "Authenticating…"
                : biometry.prompt(appName: AppBrand.name)
        case .cancelled:
            return "Unlock to continue. Tap \(biometry.title) to try again."
        case .failed:
            return "\(biometry.title) didn't match. Try again or use your passcode."
        case .lockedOut:
            return "\(biometry.title) is locked. Use your device passcode to continue."
        }
    }
}

#if DEBUG
private struct PreviewAuthenticator: BiometricAuthenticating {
    var biometryKind: BiometryKind { .faceID }
    func authenticate(reason: String, purpose: AuthPurpose) async -> BiometricResult { .cancelled }
}
#endif // DEBUG




#Preview {
    LaunchGateView(
        lockState: AppLockState(authenticator: PreviewAuthenticator()),
        autoPrompt: false
    )
}
