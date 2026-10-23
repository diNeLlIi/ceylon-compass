//
//  AppLockState.swift
//  celon-compass
//
//  Created by student2 on 2026-10-23.
//

import SwiftUI

@MainActor
@Observable
final class AppLockState {
    private(set) var isLocked = true
    private(set) var errorMessage: String?

    func authenticate() {
        Task {
            let result = await BiometricService.shared.authenticate(
                reason: "Unlock Ceylon Compass"
            )
            switch result {
            case .success:
                errorMessage = nil
                isLocked = false
            case .failure(let message):
                errorMessage = message
                isLocked = true
            }
        }
    }

    func lock() {
        isLocked = true
        errorMessage = nil
    }
}
