//
//  DeepLink.swift
//  celon-compass
//
//  Shared by the app and the widget extension: the widget builds these URLs,
//  the app parses them. Both targets compile this file.
//

import Foundation
import Observation

// An App Intent with openAppWhenRun has no URL to hand the app, so it drops its
// destination here and ContentView picks it up when the scene becomes active.
@MainActor
@Observable
final class DeepLinkInbox {
    static let shared = DeepLinkInbox()
    var pending: DeepLink?
    private init() {}
}

enum DeepLink: Equatable {
    case trip(UUID)
    case trips

    static let scheme = "celoncompass"

    var url: URL {
        switch self {
        case .trip(let id):
            URL(string: "\(Self.scheme)://trip/\(id.uuidString)")!
        case .trips:
            URL(string: "\(Self.scheme)://trips")!
        }
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        // "celoncompass://trip/<uuid>" parses as host "trip" with one path component.
        switch url.host() {
        case "trip":
            let identifier = url.pathComponents.first { $0 != "/" }
            guard let identifier, let uuid = UUID(uuidString: identifier) else { return nil }
            self = .trip(uuid)
        case "trips":
            self = .trips
        default:
            return nil
        }
    }
}
