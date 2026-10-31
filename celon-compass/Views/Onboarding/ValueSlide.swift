//
//  ValueSlide.swift
//  celon-compass
//

import SwiftUI

struct ValueSlide: View {
    let content: Content
    let isLast: Bool
    let onNext: () -> Void
    let onSkip: () -> Void

    struct Content {
        let heroImage: String
        let headline: String
        let subtext: String
        let chip: ChipVariant
    }

    enum ChipVariant {
        case weather
        case bestWindow
        case memory
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, 8)

            Spacer()

            chipView
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 12) {
                Text(content.headline)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                Text(content.subtext)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            Spacer()
                .frame(height: 40)

            Button(action: onNext) {
                Text(isLast ? "Get started" : "Next")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppBrand.tealTop, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background { heroBackground }
    }

    private var topBar: some View {
        HStack {
            BrandHeader(surface: .onBrand)
            Spacer()
            Button("Skip", action: onSkip)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var heroBackground: some View {
        Color.clear
            .overlay {
                if let uiImage = UIImage(named: content.heroImage) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    heroGradientFallback
                }
            }
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.35), .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var heroGradientFallback: some View {
        switch content.chip {
        case .weather:
            LinearGradient(
                colors: [AppBrand.tealTop, AppBrand.tealMid, AppBrand.navy],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .bestWindow:
            LinearGradient(
                colors: [AppBrand.tealTop.opacity(0.7), AppBrand.tealMid, AppBrand.navy],
                startPoint: .top,
                endPoint: .bottom
            )
        case .memory:
            LinearGradient(
                colors: [AppBrand.tealMid.opacity(0.8), AppBrand.navy, AppBrand.navy],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
    }

    @ViewBuilder
    private var chipView: some View {
        switch content.chip {
        case .weather:
            weatherChip
        case .bestWindow:
            bestWindowChip
        case .memory:
            memoryChip
        }
    }

    private var weatherChip: some View {
        HStack(spacing: 0) {
            weatherItem(icon: "sun.max", temp: "29°")
            Divider()
                .frame(height: 32)
                .overlay(Color.white.opacity(0.2))
            weatherItem(icon: "cloud.sun", temp: "30°")
            Divider()
                .frame(height: 32)
                .overlay(Color.white.opacity(0.2))
            weatherItem(icon: "cloud.rain", temp: "18°")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 24)
    }

    private func weatherItem(icon: String, temp: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.9))
            Text(temp)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    private var bestWindowChip: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppBrand.success)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dec 10 – 14")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Best window across 3 places")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 24)
    }

    private var memoryChip: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppBrand.tealMid.opacity(0.5))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.8))
                }
            VStack(alignment: .leading, spacing: 3) {
                Text("Secret waterfall")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 2) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(AppBrand.amber)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 24)
    }
}

#Preview {
    ValueSlide(
        content: .init(
            heroImage: "onboarding_weather",
            headline: "See the weather\nbefore you commit",
            subtext: "Every destination card shows its forecast up front, so you never plan a trip into the rain.",
            chip: .weather
        ),
        isLast: false,
        onNext: {},
        onSkip: {}
    )
}
