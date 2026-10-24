//
//  SettingsCard.swift
//  celon-compass
//
//  A Settings section: uppercase gray header, white rounded card, optional footer.
//

import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        Section {
            content
                .listRowBackground(AppBrand.card)
        } header: {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
        } footer: {
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
