//
//  NotificationPermission.swift
//  celon-compass
//
//  Thin wrapper over UNUserNotificationCenter to test view model 
//

import UserNotifications

protocol NotificationAuthorizing {
    // Returns true if notifications allowed.
    func requestAuthorization() async -> Bool
}

struct SystemNotificationAuthorizer: NotificationAuthorizing {
    func requestAuthorization() async -> Bool {
        // Returns false if the user previously denied it
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
}
