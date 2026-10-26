//
//  AttentionBanner.swift
//  celon-compass
//
//

import SwiftUI

struct AttentionBanner: View {
    let title: String
    let message: String
    let primaryActionTitle: String
    let primaryAction: () -> Void
    let secondaryActionTitle: String
    let secondaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppBrand.destructive)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button(action: primaryAction) {
                    Text(primaryActionTitle)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppBrand.destructive)

                Button(action: secondaryAction) {
                    Text(secondaryActionTitle)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
        .padding(12)
        .background(AppBrand.destructiveTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppBrand.destructive.opacity(0.35), lineWidth: 1)
        }
    }
}

#Preview {
    AttentionBanner(
        title: "Saturday 14 Nov is overloaded",
        message: "Mirissa and Ella are both booked, and Ella has 80% rain with 45 km/h gusts.",
        primaryActionTitle: "Move Ella to Mon 16 · clear",
        primaryAction: {},
        secondaryActionTitle: "Keep",
        secondaryAction: {}
    )
    .padding()
}
