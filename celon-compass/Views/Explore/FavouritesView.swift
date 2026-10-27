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

    @State private var isCompareMode = false
    @State private var compareSelection = CompareSelection()
    @State private var showCompare = false

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
                if destinations.count >= CompareSelection.minCount {
                    HStack {
                        Spacer()
                        compareModeButton
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }

//                Text("\(destinations.count) \(destinations.count == 1 ? "place" : "places")")
//                    .font(.subheadline)
//                    .foregroundStyle(.secondary)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.horizontal)
//                    .padding(.top, 8)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(destinations, id: \.id) { destination in
                        if isCompareMode {
                            DestinationCardView(
                                destination: destination,
                                forecast: forecasts[destination.id ?? UUID()]?.first,
                                favouritesStore: favouritesStore,
                                compareMode: compareMode(for: destination)
                            )
                        } else {
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
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .background(AppBrand.canvas)
        .navigationTitle("Favourites")
        .safeAreaInset(edge: .bottom) {
            if isCompareMode {
                CompareBottomBarView(selection: compareSelection) {
                    showCompare = true
                }
            }
        }
        .navigationDestination(isPresented: $showCompare) {
            CompareDestinationsView(
                destinations: destinations,
                forecasts: forecasts,
                selection: compareSelection
            )
        }
        .onChange(of: isCompareMode) {
            if !isCompareMode {
                compareSelection.reset()
            }
        }
    }

    private var compareModeButton: some View {
        Button {
            isCompareMode.toggle()
        } label: {
            Image(systemName: "sparkles")
                .foregroundStyle(.white)
                .padding(8)
                .background(isCompareMode ? AppBrand.tealMid : AppBrand.tealTop, in: Circle())
        }
        .accessibilityLabel(isCompareMode ? "Exit compare mode" : "Compare destinations")
    }

    private func compareMode(for destination: Destination) -> DestinationCardView.CompareMode {
        guard let id = destination.id else { return .off }
        return .selectable(
            isSelected: compareSelection.isSelected(id),
            onToggle: { compareSelection.toggle(id) }
        )
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let sigiriya = Destination(context: context)
    sigiriya.id = UUID()
    sigiriya.name = "Sigiriya"
    sigiriya.category = "Heritage"
    let ella = Destination(context: context)
    ella.id = UUID()
    ella.name = "Ella"
    ella.category = "Mountain"
    let favouritesStore = FavouritesStore(context: context)
    favouritesStore.add(sigiriya.id!)
    favouritesStore.add(ella.id!)

    return NavigationStack {
        FavouritesView(destinations: [sigiriya, ella], forecasts: [:], favouritesStore: favouritesStore)
    }
}
