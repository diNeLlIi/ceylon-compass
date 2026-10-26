//
//  CompareSelection.swift
//  celon-compass
//
//  Transient compare-mode selection state for Explore
//

import Observation
import Foundation

@Observable
final class CompareSelection {
    static let maxCount = 3
    static let minCount = 2

    private(set) var orderedIds: [UUID] = []

    var count: Int { orderedIds.count }
    var canCompare: Bool { count >= Self.minCount }
    var isFull: Bool { count >= Self.maxCount }

    func isSelected(_ id: UUID) -> Bool {
        orderedIds.contains(id)
    }

    func toggle(_ id: UUID) {
        if let index = orderedIds.firstIndex(of: id) {
            orderedIds.remove(at: index)
        } else if !isFull {
            orderedIds.append(id)
        }
    }

    func remove(_ id: UUID) {
        guard count > Self.minCount else { return }
        orderedIds.removeAll { $0 == id }
    }

    func reset() {
        orderedIds.removeAll()
    }
}
