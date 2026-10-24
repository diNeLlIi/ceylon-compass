//
//  SyncStatusStore.swift
//  celon-compass
//
//  Remembers when destinations were last refreshed from the server
//

import Foundation

struct SyncStatusStore {
    static let key = "lastSyncedAt"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastSyncedAt: Date? {
        defaults.object(forKey: Self.key) as? Date
    }

    func markSynced(at date: Date = Date()) {
        defaults.set(date, forKey: Self.key)
    }

    static func displayString(
        for date: Date?,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> String {
        guard let date else { return "Never" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }
}
