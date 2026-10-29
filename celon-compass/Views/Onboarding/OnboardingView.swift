//
//  OnboardingView.swift
//  celon-compass
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    var onFinish: () -> Void

    private let slides: [ValueSlide.Content] = [
        .init(
            heroImage: "onboarding_weather",
            headline: "See the weather\nbefore you commit",
            subtext: "Every destination card shows its forecast up front, so you never plan a trip into the rain.",
            chip: .weather
        ),
        .init(
            heroImage: "onboarding_compare",
            headline: "Compare destinations,\npick the best window",
            subtext: "Line up day-by-day forecasts across places you're considering and see which dates work best.",
            chip: .bestWindow
        ),
        .init(
            heroImage: "onboarding_memories",
            headline: "Find gems along the\nway, keep the memories",
            subtext: "Discover hidden gems along your route, and save photos and ratings from every stop.",
            chip: .memory
        )
    ]

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                ValueSlide(
                    content: slide,
                    isLast: index == slides.count - 1,
                    onNext: advance,
                    onSkip: onFinish
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .background(Color.black)
    }

    private func advance() {
        if currentPage < slides.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage += 1
            }
        } else {
            onFinish()
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
