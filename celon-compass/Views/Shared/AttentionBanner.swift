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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.footnote)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(AppBrand.destructive)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(action: primaryAction) {
                    Text(primaryActionTitle)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppBrand.destructive)

                Button(action: secondaryAction) {
                    Text(secondaryActionTitle)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .frame(minHeight: 24)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.bordered)
                .tint(AppBrand.heading)
            }
            .padding(.top, 2)
        }
        .padding(14)
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
        primaryActionTitle: "Move to Mon 16 · clear",
        primaryAction: {},
        secondaryActionTitle: "Keep",
        secondaryAction: {}
    )
    .padding()
}
