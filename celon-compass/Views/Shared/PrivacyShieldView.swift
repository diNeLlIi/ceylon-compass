//
//  PrivacyShieldView.swift
//  celon-compass
//
//

import SwiftUI

struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            BrandBackground()
            VStack(spacing: 16) {
                CompassMark(size: 96)
                Text(AppBrand.name)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    PrivacyShieldView()
}
