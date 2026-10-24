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

    var body: some View {
        ZStack {
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
        .animation(.easeInOut(duration: 0.3), value: lockState.isLocked)
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
