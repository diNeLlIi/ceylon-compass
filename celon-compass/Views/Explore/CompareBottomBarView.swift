//
//  CompareBottomBarView.swift
//  celon-compass
//

import SwiftUI

struct CompareBottomBarView: View {
    @Bindable var selection: CompareSelection
    let onCompare: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Select up to \(CompareSelection.maxCount) destinations, then tap Compare.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Text("\(selection.count) of \(CompareSelection.maxCount) selected")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button("Compare", action: onCompare)
                    .buttonStyle(.borderedProminent)
                    .tint(AppBrand.accentStrong)
                    .disabled(!selection.canCompare)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}

#Preview {
    CompareBottomBarView(selection: CompareSelection(), onCompare: {})
}
