//
//  LaunchGateView.swift
//  celon-compass
//
//  Created by student2 on 2026-10-23.
//

import SwiftUI

struct LaunchGateView: View {
    var lockState: AppLockState

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "faceid")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)

                Text("Ceylon Compass is locked")
                    .font(.headline)

                if let errorMessage = lockState.errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button("Try Again") {
                    lockState.authenticate()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear {
            lockState.authenticate()
        }
    }
}

#Preview {
    LaunchGateView(lockState: AppLockState())
}
