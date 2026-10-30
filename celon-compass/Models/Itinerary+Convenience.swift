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
}
