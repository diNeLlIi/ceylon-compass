//
//  SecurityView.swift
//  celon-compass
//
//  Face ID / Touch ID lock toggle
//

import SwiftUI

struct SecurityView: View {
    @State private var faceIDEnabled = PreferencesStore.shared.faceIDLockEnabled
    private let biometry = BiometricService.shared.biometryKind

    var body: some View {
        List {
            SettingsCard(
                title: "App Lock",
                footer: footerText
            ) {
                Toggle(biometry.title, isOn: $faceIDEnabled)
                    .tint(AppBrand.success)
                    .onChange(of: faceIDEnabled) { _, newValue in
                        PreferencesStore.shared.faceIDLockEnabled = newValue
                    }
                    .disabled(biometry == .noBiometry)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppBrand.canvas)
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var footerText: String {
        if biometry == .noBiometry {
            return "No biometric authentication is available on this device. Set up Face ID or Touch ID in iOS Settings."
        }
        return "\(biometry.title) will be required when you reopen \(AppBrand.name)."
    }
}
