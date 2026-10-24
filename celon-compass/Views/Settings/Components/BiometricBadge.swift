//
//  BiometricBadge.swift
//  celon-compass
//
//  Red capsule that tells the user an action will ask for Face ID / Touch ID / Optic ID.
//

import SwiftUI

struct BiometricBadge: View {
    let kind: BiometryKind

    var body: some View {
        Label(kind.title, systemImage: kind.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppBrand.destructive)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppBrand.destructiveTint, in: Capsule())
            .accessibilityLabel("Requires \(kind.title)")
    }
}

#Preview {
    BiometricBadge(kind: .faceID)
}
