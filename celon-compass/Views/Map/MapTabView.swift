//
//  MapTabView.swift
//  celon-compass
//

import SwiftUI

struct MapTabView: View {
    var body: some View {
        ComingSoonView(
            title: "Map",
            symbol: "map",
            message: "See your destinations and routes on an offline-ready map."
        )
    }
}

#Preview { MapTabView() }
