//
//  CompareSelectionTests.swift
//  celon-compassTests
//

import Testing
import Foundation
@testable import celon_compass

struct CompareSelectionTests {

    @Test func togglingAddsUpToTheMaximumOfThree() {
        let selection = CompareSelection()
        let ids = (0..<4).map { _ in UUID() }

        for id in ids { selection.toggle(id) }

        #expect(selection.count == CompareSelection.maxCount)
        #expect(!selection.isSelected(ids[3]))
        #expect(selection.isFull)
    }

    @Test func togglingRemovesAnAlreadySelectedId() {
        let selection = CompareSelection()
        let id = UUID()

        selection.toggle(id)
        #expect(selection.isSelected(id))

        selection.toggle(id)
        #expect(!selection.isSelected(id))
    }

    @Test func resetClearsEverything() {
        let selection = CompareSelection()
        selection.toggle(UUID())
        selection.toggle(UUID())

        selection.reset()

        #expect(selection.count == 0)
    }

    @Test func canCompareIsFalseBelowMinimumAndTrueAtIt() {
        let selection = CompareSelection()
        #expect(!selection.canCompare)

        selection.toggle(UUID())
        #expect(!selection.canCompare)

        selection.toggle(UUID())
        #expect(selection.canCompare)
    }

    @Test func removeIsANoOpAtTheMinimumFloor() {
        let selection = CompareSelection()
        let first = UUID()
        let second = UUID()
        selection.toggle(first)
        selection.toggle(second)

        selection.remove(first)

        #expect(selection.count == CompareSelection.minCount, "removing below the floor must be a no-op")
        #expect(selection.isSelected(first))
    }
}
