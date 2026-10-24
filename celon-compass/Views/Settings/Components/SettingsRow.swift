//
//  SettingsRow.swift
//  celon-compass
//
//  One Settings row: optional icon, title, optional subtitle, trailing content, optional chevron.
//

import SwiftUI

struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var icon: String?
    var tint: Color = .primary
    var showsChevron = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(tint)
                    .frame(width: 24)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(tint)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            trailing

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        tint: Color = .primary,
        showsChevron: Bool = false
    ) {
        self.init(title: title, subtitle: subtitle, icon: icon, tint: tint, showsChevron: showsChevron) {
            EmptyView()
        }
    }
}
