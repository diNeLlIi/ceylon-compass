//
//  DoubleBookedNoticeView.swift
//  celon-compass
//
//

import SwiftUI

struct DoubleBookedNoticeView: View {
    let title: String
    let message: String
    let fixAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(AppBrand.amber)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: fixAction) {
                Text("Fix")
                    .font(.subheadline.weight(.semibold))
                    .underline()
                    .foregroundStyle(AppBrand.navy)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(AppBrand.amberTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppBrand.amber.opacity(0.4), lineWidth: 1)
        }
    }
}

#Preview {
    DoubleBookedNoticeView(
        title: "Two stops on Nov 14",
        message: "Mirissa and Ella are both scheduled for Saturday.",
        fixAction: {}
    )
    .padding()
}
