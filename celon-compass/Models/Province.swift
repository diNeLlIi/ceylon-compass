//
//  Province.swift
//  celon-compass
//
//  The 9 administrative provinces of Sri Lanka. District is deliberately not modelled:
//  the catalog carries one, but nothing filters on it.
//

import Foundation

enum Province: String, CaseIterable, Identifiable {
    case western = "Western"
    case central = "Central"
    case southern = "Southern"
    case northern = "Northern"
    case eastern = "Eastern"
    case northWestern = "North Western"
    case northCentral = "North Central"
    case uva = "Uva"
    case sabaragamuwa = "Sabaragamuwa"

    var id: String { rawValue }

    var displayName: String { rawValue }

    // Catalog rows reach us from two sources — the bundled seed and Firestore — and only
    // the first is under version control. Anything that differs from the canonical string
    // by case, padding, or a trailing "Province" is folded in rather than dropped, because
    // a destination that matches no province is invisible to the filter forever.
    static func normalised(from raw: String?) -> Province? {
        guard let raw else { return nil }
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.lowercased().hasSuffix(" province") {
            cleaned = String(cleaned.dropLast(" province".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !cleaned.isEmpty else { return nil }
        return allCases.first { $0.rawValue.caseInsensitiveCompare(cleaned) == .orderedSame }
    }

    func matches(_ provinceRawValue: String?) -> Bool {
        Self.normalised(from: provinceRawValue) == self
    }
}
