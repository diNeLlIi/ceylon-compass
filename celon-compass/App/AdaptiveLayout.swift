//
//  AdaptiveLayout.swift
//  celon-compass
//
//  One place to answer "is this iPad-width" so every adapted screen branches the same
//  way. Size class, not UIDevice.current.userInterfaceIdiom: an iPad in Split View or
//  Slide Over reports .compact while still being an iPad, and an iPhone 16 Pro Max in
//  landscape reports .regular — idiom would get both of those backwards.
//

import SwiftUI

extension EnvironmentValues {
    var isRegularWidth: Bool { horizontalSizeClass == .regular }
}
