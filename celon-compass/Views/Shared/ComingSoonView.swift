//
//  ComingSoonView.swift
//  celon-compass
//
//  Placeholder for tabs whose screens are not built yet.
//

import SwiftUI

struct ComingSoonView: View {
    let title: String
    let symbol: String
    let message: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "\(title) is coming soon",
                systemImage: symbol,
                description: Text(message)
            )
            .navigationTitle(title)
            .background(AppBrand.canvas)
        }
    }
}
