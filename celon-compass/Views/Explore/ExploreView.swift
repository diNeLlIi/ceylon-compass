//
//  ExploreView.swift
//  celon-compass

import SwiftUI

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @State private var isCompareMode = false
    @State private var compareSelection = CompareSelection()
    @State private var showCompare = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading && viewModel.destinations.isEmpty {
                        SkeletonGridView()
                            .padding(.top, 8)
                    } else if let loadErrorMessage = viewModel.loadErrorMessage {
                        ContentUnavailableView(
                            "Couldn't load destinations",
                            systemImage: "wifi.slash",
                            description: Text("\(loadErrorMessage) Pull to refresh to try again.")
                        )
                        .padding(.top, 40)
                    } else {
                        heroSection

                        weatherSummary

                        CategoryChipsView(selectedCategory: $viewModel.selectedCategory)

                        bestWeatherSection

                        destinationsGridSection
                    }
                }
                .padding(.bottom, 16)
            }
            .navigationTitle("Explore Sri Lanka")
            .searchable(text: $viewModel.searchText, prompt: "Search destinations")
            .task { await viewModel.load() }
            .refreshable { await viewModel.refresh() }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    favouritesButton
                    compareModeButton
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isCompareMode {
                    CompareBottomBarView(selection: compareSelection) {
                        showCompare = true
                    }
                }
            }
            .navigationDestination(isPresented: $showCompare) {
                CompareDestinationsView(
                    destinations: viewModel.destinations,
                    forecasts: viewModel.forecasts,
                    selection: compareSelection
                )
            }
            .onChange(of: isCompareMode) {
                if !isCompareMode {
                    compareSelection.reset()
                }
            }
        }
    }

    
    //Compare Mode

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
        guard isCompareMode, let id = destination.id else { return .off }
        return .selectable(
            isSelected: compareSelection.isSelected(id),
            onToggle: { compareSelection.toggle(id) }
        )
    }

    private var favouritesButton: some View {
        NavigationLink {
            FavouritesView(
                destinations: viewModel.favouriteDestinations,
                forecasts: viewModel.forecasts,
                favouritesStore: viewModel.favouritesStore
            )
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(AppBrand.amber, in: Circle())

                if !viewModel.favouriteDestinations.isEmpty {
                    Text("\(viewModel.favouriteDestinations.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(AppBrand.tealMid, in: Circle())
                        .offset(x: 5, y: -5)
                }
            }
        }
        .accessibilityLabel("Favourites, \(viewModel.favouriteDestinations.count) saved")
    }


    @ViewBuilder
    private var heroSection: some View {
        if !isCompareMode, viewModel.searchText.isEmpty, let pick = viewModel.todaysPick {
            HeroDestinationView(
                destination: pick,
                forecast: viewModel.forecast(for: pick),
                favouritesStore: viewModel.favouritesStore
            )
        }
    }

    //Weather Summary
    @ViewBuilder
    private var weatherSummary: some View {
        if !viewModel.forecasts.isEmpty, viewModel.searchText.isEmpty {
            WeatherSummaryView(
                sunnyCount: viewModel.sunnyCount,
                rainyCount: viewModel.rainyCount,
                totalCount: viewModel.destinations.count
            )
        }
    }


    //Best Weather

    private var showBestWeatherSection: Bool {
        !isCompareMode
            && viewModel.searchText.isEmpty
            && viewModel.selectedCategory == .all
            && !viewModel.bestWeatherDestinations.isEmpty
    }

    private var bestWeatherCarouselDestinations: [Destination] {
        Array(viewModel.bestWeatherDestinations.prefix(5))
    }

    // Destinations already surfaced in the hero card
    //  grid below doesn't repeat them
    private var featuredDestinationIDs: Set<UUID> {
        guard showBestWeatherSection else { return [] }
        return Set(bestWeatherCarouselDestinations.compactMap(\.id))
    }

    @ViewBuilder
    private var bestWeatherSection: some View {
        if showBestWeatherSection {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Best Weather Now", systemImage: "sun.max.fill")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(bestWeatherCarouselDestinations, id: \.id) { destination in
                            DestinationFeatureCardView(
                                destination: destination,
                                forecast: viewModel.forecast(for: destination),
                                favouritesStore: viewModel.favouritesStore
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }


    //Destinations Grid

    private var gridDestinations: [Destination] {
        let excludedIDs = featuredDestinationIDs
        guard !excludedIDs.isEmpty else { return viewModel.filteredDestinations }
        return viewModel.filteredDestinations.filter { destination in
            guard let id = destination.id else { return true }
            return !excludedIDs.contains(id)
        }
    }

    @ViewBuilder
    private var destinationsGridSection: some View {
        if viewModel.filteredDestinations.isEmpty {
            emptyState
                .padding(.top, 40)
        } else {
            let items = gridDestinations
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(items.count) \(items.count == 1 ? "place" : "places")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(items, id: \.id) { destination in
                            DestinationCardView(
                                destination: destination,
                                forecast: viewModel.forecast(for: destination),
                                compareMode: compareMode(for: destination)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !viewModel.searchText.isEmpty {
            ContentUnavailableView.search(text: viewModel.searchText)
        } else {
            ContentUnavailableView(
                "No destinations",
                systemImage: "safari",
                description: Text("No destinations in this category yet.")
            )
        }
    }
}

#Preview { ExploreView() }
