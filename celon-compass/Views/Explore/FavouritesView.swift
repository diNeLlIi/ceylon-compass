//
//  FavouritesView.swift
//  celon-compass
//

import SwiftUI
import CoreData

struct FavouritesView: View {
    let destinations: [Destination]
    let forecasts: [UUID: [DayForecast]]
    var favouritesStore: FavouritesStore = .shared

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            if destinations.isEmpty {
                ContentUnavailableView(
                    "No favourites yet",
                    systemImage: "heart",
                    description: Text("Tap the heart on any destination to save it here.")
                )
                .padding(.top, 80)
            } else {
//                Text("\(destinations.count) \(destinations.count == 1 ? "place" : "places")")
//                    .font(.subheadline)
//                    .foregroundStyle(.secondary)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.horizontal)
//                    .padding(.top, 8)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(destinations, id: \.id) { destination in
                        NavigationLink(value: destination) {
                            DestinationCardView(
                                destination: destination,
                                forecast: forecasts[destination.id ?? UUID()]?.first,
                                favouritesStore: favouritesStore
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .background(AppBrand.canvas)
        .navigationTitle("Favourites")
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let destination = Destination(context: context)
    destination.id = UUID()
    destination.name = "Sigiriya"
    destination.category = "Heritage"
    let favouritesStore = FavouritesStore(context: context)
    favouritesStore.add(destination.id!)

    return NavigationStack {
        FavouritesView(destinations: [destination], forecasts: [:], favouritesStore: favouritesStore)
    }
}
