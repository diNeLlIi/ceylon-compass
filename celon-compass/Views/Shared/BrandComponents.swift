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

enum BrandSurface {
    case onBrand
    case onSurface

    var ink: Color {
        switch self {
        case .onBrand: .white
        case .onSurface: AppBrand.heading
        }
    }
}

struct CompassMark: View {
    var size: CGFloat = 96

    var body: some View {
        
        Image(.brandMark)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}


struct BrandHeader: View {
    var surface: BrandSurface = .onSurface
    var markSize: CGFloat = 22
    var fontSize: CGFloat = 15

    var body: some View {
        HStack(spacing: 7) {
            CompassMark(size: markSize)
            Text(AppBrand.name)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(surface.ink)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppBrand.name)
        .accessibilityAddTraits(.isHeader)
    }
}

extension View {
 
    func brandToolbar() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BrandHeader()
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview("On brand") {
    ZStack {
        BrandBackground()
        VStack(spacing: 32) {
            CompassMark(size: 120)
            BrandHeader(surface: .onBrand)
        }
    }
}

#Preview("On surface") {
    VStack(spacing: 32) {
        CompassMark(size: 120)
        BrandHeader()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppBrand.canvas)
}
