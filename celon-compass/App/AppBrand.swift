//
//  AppBrand.swift
//  celon-compass
//
//

import SwiftUI

enum AppBrand {
    static let name = "WanderLanka"
    static let tagline = "Plan around the weather, not into it"
    static let tealTop = Color(red: 0.200, green: 0.540, blue: 0.600)
    static let tealMid = Color(red: 0.040, green: 0.360, blue: 0.470)
    static let navy = Color(red: 0.035, green: 0.160, blue: 0.260)
    static let amber = Color(red: 0.950, green: 0.660, blue: 0.230)
    static let successSolid = Color(red: 0.180, green: 0.600, blue: 0.360)
    static let destructiveSolid = Color(red: 0.700, green: 0.150, blue: 0.120)
    static let linkSolid = Color(red: 0.055, green: 0.470, blue: 0.520)

    // surfaces
    static let canvas = Color(.brandCanvas)
    static let card = Color(.brandCard)
    //A card  on top of another card
    static let cardRaised = Color(.brandCardRaised)

    static let cardHighlight = Color(.brandCardHighlight)
    static let hairline = Color(.brandHairline)

    // Foregrounds
    static let heading = Color(.brandHeading)
    static let accent = Color(.brandAccent)
    static let accentStrong = Color(.brandAccentStrong)
    static let link = Color(.brandLink)
    static let success = Color(.brandSuccess)
    static let destructive = Color(.brandDestructive)

    // Tints
    static let destructiveTint = Color(.brandDestructiveTint)
    static let amberTint = Color(.brandAmberTint)
    static let accentTint = Color(.brandAccentTint)

    static let privacyPolicyURL: URL? = nil
}
