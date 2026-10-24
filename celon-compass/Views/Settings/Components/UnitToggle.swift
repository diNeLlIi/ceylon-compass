//
//  UnitToggle.swift
//  celon-compass
//
//  Custom °C / °F pill. VoiceOver sees it as a segmented Picker.
//

import SwiftUI

struct UnitToggle: View {
    @Binding var selection: TemperatureUnit
    @Namespace private var thumbNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TemperatureUnit.allCases) { unit in
                let isSelected = selection == unit
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = unit }
                } label: {
                    Text(unit.symbol)
                        .font(.subheadline.weight(isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .frame(width: 54, height: 30)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(.black.opacity(0.12), lineWidth: 0.5)
                                    )
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "thumb", in: thumbNamespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(AppBrand.canvas, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.black.opacity(0.08), lineWidth: 0.5)
        )
        .accessibilityRepresentation {
            Picker("Temperature", selection: $selection) {
                ForEach(TemperatureUnit.allCases) { unit in
                    Text(unit.name).tag(unit)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

#Preview {
    @Previewable @State var unit = TemperatureUnit.celsius
    UnitToggle(selection: $unit)
        .padding()
}
