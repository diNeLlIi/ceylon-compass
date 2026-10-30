//
//  RadiusSliderView.swift
//  celon-compass
//
//  Search-radius slider for Plan a Trip
//

import SwiftUI

struct RadiusSliderView: View {
    let range: ClosedRange<Double>
    let placesInRange: Int
    let onCommit: (Double) -> Void

    @State private var liveValue: Double

    init(initialValue: Double, range: ClosedRange<Double>, placesInRange: Int, onCommit: @escaping (Double) -> Void) {
        self._liveValue = State(initialValue: initialValue)
        self.range = range
        self.placesInRange = placesInRange
        self.onCommit = onCommit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Search radius")
                        .font(.subheadline.weight(.semibold))
                    Text("\(placesInRange) places within range")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(liveValue)) km")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppBrand.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppBrand.accentTint, in: Capsule())
            }

            Slider(
                value: $liveValue,
                in: range,
                step: 1,
                onEditingChanged: { isEditing in
                    if !isEditing {
                        onCommit(liveValue)
                    }
                }
            )
            .tint(AppBrand.accent)

            HStack {
                Text("\(Int(range.lowerBound)) km")
                Spacer()
                Text("\(Int(range.upperBound)) km")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RadiusSliderView(initialValue: 25, range: 5...50, placesInRange: 18) { _ in }
        .padding()
}
