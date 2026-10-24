//
//  BrandComponents.swift
//  celon-compass
//
//  Shared visual building blocks for the lock screen and privacy shield.
//

import SwiftUI

struct BrandBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppBrand.tealTop, AppBrand.tealMid, AppBrand.navy],
                startPoint: .top,
                endPoint: .bottom
            )

            Canvas { context, size in
                drawRings(
                    in: &context,
                    center: CGPoint(x: size.width * 0.18, y: size.height * 0.10),
                    baseSize: CGSize(width: 150, height: 105),
                    step: CGSize(width: 105, height: 78),
                    count: 5
                )
                drawRings(
                    in: &context,
                    center: CGPoint(x: size.width * 0.85, y: size.height * 0.86),
                    baseSize: CGSize(width: 190, height: 160),
                    step: CGSize(width: 115, height: 100),
                    count: 6
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func drawRings(
        in context: inout GraphicsContext,
        center: CGPoint,
        baseSize: CGSize,
        step: CGSize,
        count: Int
    ) {
        for index in 0..<count {
            let width = baseSize.width + step.width * CGFloat(index)
            let height = baseSize.height + step.height * CGFloat(index)
            let rect = CGRect(
                x: center.x - width / 2,
                y: center.y - height / 2,
                width: width,
                height: height
            )
            let opacity = 0.16 - Double(index) * 0.018
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(max(opacity, 0.04))),
                lineWidth: 1
            )
        }
    }
}

struct CompassMark: View {
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.35), lineWidth: max(size * 0.014, 1))

            // Crosshair lines running through the mark.
            Rectangle()
                .fill(.white.opacity(0.35))
                .frame(width: max(size * 0.01, 1), height: size)
            Rectangle()
                .fill(.white.opacity(0.35))
                .frame(width: size, height: max(size * 0.01, 1))

            Circle()
                .inset(by: size * 0.08)
                .stroke(AppBrand.amber, lineWidth: size * 0.035)

            CompassStar()
                .fill(.white)
                .frame(width: size * 0.72, height: size * 0.72)
                .shadow(color: .black.opacity(0.25), radius: size * 0.04, y: size * 0.02)

            Circle()
                .fill(AppBrand.tealTop)
                .overlay(Circle().stroke(.white, lineWidth: size * 0.02))
                .frame(width: size * 0.13, height: size * 0.13)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct CompassStar: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.2
        var path = Path()
        for index in 0..<8 {
            let angle = Double(index) * .pi / 4 - .pi / 2
            let radius = index.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        BrandBackground()
        CompassMark(size: 120)
    }
}
