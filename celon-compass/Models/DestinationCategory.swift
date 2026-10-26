//
//  DestinationCategory.swift
//  celon-compass
//

import Foundation

enum DestinationCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case beach = "Beach"
    case mountain = "Mountain"
    case heritage = "Heritage"
    case wildlife = "Wildlife"

    var id: String { rawValue }

    // Case-insensitive so a casing drift in the catalog data doesn't silently
    // drop a destination out of every filter.
    func matches(_ categoryRawValue: String?) -> Bool {
        guard self != .all else { return true }
        guard let categoryRawValue else { return false }
        return categoryRawValue.caseInsensitiveCompare(rawValue) == .orderedSame
    }
}
