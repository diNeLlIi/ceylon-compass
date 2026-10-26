//
//  TabRouter.swift
//  celon-compass
//
//

import Observation

@MainActor
@Observable
final class TabRouter {
    var selection: AppTab = .trips
}
