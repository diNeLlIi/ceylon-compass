//
//  PasswordField.swift
//  celon-compass
//
//  Password input with show/hide eye toggle and optional strength meter.
//

import SwiftUI

struct PasswordField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var isVisible: Bool
    var strength: PasswordStrength?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Group {
                    if isVisible {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .textContentType(.password)
                .autocorrectionDisabled()

                Button {
                    isVisible.toggle()
                } label: {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Color(.systemGray6),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            if let strength {
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(strengthColor(strength))
                            .frame(width: geo.size.width * strength.fraction, height: 4)
                            .animation(.easeInOut(duration: 0.2), value: strength.fraction)
                    }
                    .frame(height: 4)

                    Text(strength.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func strengthColor(_ strength: PasswordStrength) -> Color {
        switch strength {
        case .tooShort: AppBrand.destructive
        case .weak: .orange
        case .fair: AppBrand.amber
        case .strong: AppBrand.success
        }
    }
}
