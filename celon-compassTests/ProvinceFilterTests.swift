//
//  ProvinceFilterTests.swift
//  celon-compassTests
//

import Testing
import CoreData
@testable import celon_compass

@MainActor
struct ProvinceFilterTests {

    private func destination(_ name: String, category: String, province: String) -> Destination {
        let destination = Destination(context: TestStore.context)
        destination.id = UUID()
        destination.name = name
        destination.category = category
        destination.province = province
        return destination
    }

    private var catalog: [Destination] {
        [
            destination("Mirissa", category: "Beach", province: "Southern"),
            destination("Galle Fort", category: "Heritage", province: "Southern"),
            destination("Ella", category: "Mountain", province: "Uva"),
            destination("Kandy", category: "Heritage", province: "Central"),
            destination("Sigiriya", category: "Heritage", province: "Central")
        ]
    }

    @Test func allFiltersOffReturnsEverything() {
        let result = ExploreViewModel.filter(catalog, category: .all, province: nil, searchText: "")
        #expect(result.count == 5)
    }

    @Test func provinceAloneNarrowsToThatProvince() {
        let result = ExploreViewModel.filter(catalog, category: .all, province: .southern, searchText: "")
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.province == "Southern" })
    }

    @Test func provinceAndCategoryAreAndedNotOred() {
        let result = ExploreViewModel.filter(catalog, category: .heritage, province: .southern, searchText: "")
        #expect(result.count == 1)
        #expect(result.first?.name == "Galle Fort")
    }

    @Test func provinceAndSearchCombine() {
        let result = ExploreViewModel.filter(catalog, category: .all, province: .central, searchText: "kan")
        #expect(result.count == 1)
        #expect(result.first?.name == "Kandy")
    }

    @Test func allThreeFiltersCombine() {
        let result = ExploreViewModel.filter(catalog, category: .heritage, province: .central, searchText: "sig")
        #expect(result.count == 1)
        #expect(result.first?.name == "Sigiriya")
    }

    @Test func combinationWithNoMatchesReturnsEmpty() {
        let result = ExploreViewModel.filter(catalog, category: .beach, province: .uva, searchText: "")
        #expect(result.isEmpty)
    }

    @Test func provinceWithNoCatalogEntriesReturnsEmpty() {
        let result = ExploreViewModel.filter(catalog, category: .all, province: .northern, searchText: "")
        #expect(result.isEmpty)
    }

    @Test func whitespaceOnlySearchIsTreatedAsNoSearch() {
        let result = ExploreViewModel.filter(catalog, category: .all, province: nil, searchText: "   ")
        #expect(result.count == 5)
    }

    // A destination whose province string drifted must still be reachable by the filter,
    // otherwise it is invisible in Explore with no way for the user to find it.
    @Test(arguments: [
        "Southern",
        "southern",
        "  Southern  ",
        "Southern Province",
        "southern province"
    ])
    func normalisationFoldsCasingPaddingAndTheProvinceSuffix(raw: String) {
        #expect(Province.normalised(from: raw) == .southern)
    }

    @Test func normalisationRejectsUnknownAndEmptyValues() {
        #expect(Province.normalised(from: nil) == nil)
        #expect(Province.normalised(from: "") == nil)
        #expect(Province.normalised(from: "   ") == nil)
        #expect(Province.normalised(from: "Atlantis") == nil)
    }

    @Test func matchesUsesNormalisationSoDriftedRowsStillFilter() {
        let drifted = destination("Tangalle", category: "Beach", province: "southern province")
        let result = ExploreViewModel.filter([drifted], category: .all, province: .southern, searchText: "")
        #expect(result.count == 1)
    }

    @Test func thereAreNineProvinces() {
        #expect(Province.allCases.count == 9)
    }
}
