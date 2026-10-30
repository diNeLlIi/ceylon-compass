//
//  AppTab.swift
//  celon-compass
//
//

import Foundation

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case explore
    case map
    case trips
    case memories
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explore: "Explore"
        case .map: "Map"
        case .trips: "My Trips"
        case .memories: "Memories"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .explore: "safari"
        case .map: "map"
        case .trips: "briefcase"
        case .memories: "square.on.square"
        case .settings: "gear"
        }
    }
}
