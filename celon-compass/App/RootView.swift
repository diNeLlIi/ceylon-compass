//
//  RootView.swift
//  celon-compass
//
//  Created by student2 on 2026-10-24.
//  decides what is on screen: protected content after face rec
//

import SwiftUI

struct RootView: View {
    var lockState: AppLockState
    @Environment(\.scenePhase) private var scenePhase
    @State private var showOnboarding = !PreferencesStore.shared.hasOnboarded
    @State private var showPreferences = false

    var body: some View {
        ZStack {
            if showOnboarding {
                if showPreferences {
                    PreferencesSetupView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showOnboarding = false
                            showPreferences = false
                        }
                    }
                    .transition(.move(edge: .trailing))
                } else {
                    OnboardingView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPreferences = true
                        }
                    }
                    .transition(.opacity)
                }
            } else {
                if lockState.hasUnlockedOnce {
                    ContentView()
                        .safeAreaInset(edge: .top, spacing: 0) { noticeBanner }
                        .allowsHitTesting(!lockState.isLocked)
                        .accessibilityHidden(lockState.isLocked)
                }

                if lockState.isLocked {
                    LaunchGateView(lockState: lockState)
                        .transition(.opacity)
                } else if scenePhase != .active {
                    PrivacyShieldView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: lockState.isLocked)
        .animation(.easeInOut(duration: 0.3), value: showOnboarding)
    }

    @ViewBuilder
    private var noticeBanner: some View {
        if let notice = lockState.notice, !lockState.isLocked {
            Label(notice, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppBrand.tealMid)
        }
    }
}
