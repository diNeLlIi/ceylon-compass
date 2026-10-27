//
//  ExploreView.swift
//  celon-compass

import SwiftUI

private enum ExploreRoute: Hashable {
    case favourites
}

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @State private var isCompareMode = false
    @State private var compareSelection = CompareSelection()
    @State private var showCompare = false
    @State private var showNavigationTitle = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    exploreHeader

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
                        CategoryChipsView(selectedCategory: $viewModel.selectedCategory)

                        bentoSection

                        destinationsGridSection
                    }
                }
                .padding(.bottom, 72)
            }
            .background(AppBrand.canvas)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y > 36
            } action: { _, isScrolled in
                showNavigationTitle = isScrolled
            }
            .navigationTitle(showNavigationTitle ? "Explore" : "")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
            .refreshable { await viewModel.refresh() }
            .safeAreaInset(edge: .bottom) {
                if isCompareMode {
                    CompareBottomBarView(selection: compareSelection) {
                        showCompare = true
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !isCompareMode {
                    searchBar
                }
            }
            .navigationDestination(isPresented: $showCompare) {
                CompareDestinationsView(
                    destinations: viewModel.destinations,
                    forecasts: viewModel.forecasts,
                    selection: compareSelection
                )
            }
            .navigationDestination(for: Destination.self) { destination in
                DestinationDetailView(
                    destination: destination,
                    forecasts: viewModel.forecasts[destination.id ?? UUID()] ?? [],
                    favouritesStore: viewModel.favouritesStore
                )
            }
            .navigationDestination(for: ExploreRoute.self) { route in
                switch route {
                case .favourites:
                    FavouritesView(
                        destinations: viewModel.favouriteDestinations,
                        forecasts: viewModel.forecasts,
                        favouritesStore: viewModel.favouritesStore
                    )
                }
            }
            .onChange(of: isCompareMode) {
                if !isCompareMode {
                    compareSelection.reset()
                }
            }
        }
    }

    private var exploreHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Explore")
                .font(.largeTitle.bold())

            Spacer()

            HStack(spacing: 10) {
                favouritesButton
                compareModeButton
            }
        }
        .padding(.horizontal)
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
        NavigationLink(value: ExploreRoute.favourites) {
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


    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(.darkGray))
            TextField("", text: $viewModel.searchText, prompt: Text("Search destinations").foregroundStyle(Color(.darkGray)))
                .font(.body)
                .foregroundStyle(Color(.darkGray))
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(.darkGray))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var showBentoSection: Bool {
        !isCompareMode
            && viewModel.searchText.isEmpty
            && viewModel.selectedCategory == .all
            && viewModel.todaysPick != nil
    }

    private var bentoRunners: [Destination] {
        Array(viewModel.bestWeatherDestinations.prefix(2))
    }

    private var featuredDestinationIDs: Set<UUID> {
        guard showBentoSection, let pick = viewModel.todaysPick else { return [] }
        return Set(([pick] + bentoRunners).compactMap(\.id))
    }

    @ViewBuilder
    private var bentoSection: some View {
        if showBentoSection, let pick = viewModel.todaysPick {
            BestWeatherBentoView(
                topPick: pick,
                runners: bentoRunners,
                forecasts: viewModel.forecasts,
                favouritesStore: viewModel.favouritesStore
            )
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
//                    Text("\(items.count) \(items.count == 1 ? "place" : "places")")
//                        .font(.subheadline)
//                        .foregroundStyle(.secondary)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .padding(.horizontal)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(items, id: \.id) { destination in
                            if isCompareMode {
                                DestinationCardView(
                                    destination: destination,
                                    forecast: viewModel.forecast(for: destination),
                                    compareMode: compareMode(for: destination)
                                )
                            } else {
                                NavigationLink(value: destination) {
                                    DestinationCardView(
                                        destination: destination,
                                        forecast: viewModel.forecast(for: destination)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
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
