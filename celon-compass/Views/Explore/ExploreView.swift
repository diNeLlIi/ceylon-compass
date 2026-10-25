//
//  ExploreView.swift
//  celon-compass

import SwiftUI

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    CategoryChipsView(selectedCategory: $viewModel.selectedCategory)
                        .padding(.bottom, 12)

                    content
                        .padding(.horizontal)
                }
            }
            .navigationTitle("Explore")
            .searchable(text: $viewModel.searchText, prompt: "Search destinations")
            .task { await viewModel.load() }
            .refreshable { await viewModel.refresh() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.destinations.isEmpty {
            ProgressView()
                .padding(.top, 80)
        } else if let loadErrorMessage = viewModel.loadErrorMessage {
            ContentUnavailableView(
                "Couldn't load destinations",
                systemImage: "wifi.slash",
                description: Text("\(loadErrorMessage) Pull to refresh to try again.")
            )
            .padding(.top, 40)
        } else if viewModel.filteredDestinations.isEmpty {
            emptyState
                .padding(.top, 40)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.filteredDestinations, id: \.id) { destination in
                    DestinationCardView(
                        destination: destination,
                        forecast: viewModel.forecasts[destination.id ?? UUID()]?.first
                    )
                }
            }
            .padding(.bottom, 16)
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
