//
//  Itinerary+Convenience.swift
//  celon-compass
//
//  Computed helpers for trip state. endDate answers "is this trip over?",
//  completedAt answers "has the user reviewed it?"
//

import Foundation

extension Itinerary {
    /// True when endDate is before the start of today.
    var isCompleted: Bool {
        guard let endDate else { return false }
        return endDate < Calendar.current.startOfDay(for: .now)
    }

    /// True when the trip is over but the user hasn't reviewed it yet.
    var needsReview: Bool {
        isCompleted && completedAt == nil
    }

    enum Lifecycle: String {
        case planning = "Planning"
        case active = "Active"
        case completed = "Completed"
    }

    func lifecycle(now: Date = .now, calendar: Calendar = .current) -> Lifecycle {
        if completedAt != nil { return .completed }
        let today = calendar.startOfDay(for: now)
        if let endDate, endDate < today { return .completed }
        if let startDate, startDate > today { return .planning }
        // No dates yet means nothing has been scheduled, so it is still being planned.
        return startDate == nil ? .planning : .active
    }
}
