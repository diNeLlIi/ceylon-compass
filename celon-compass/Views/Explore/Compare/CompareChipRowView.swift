//
//  CompareChipRowView.swift
//  celon-compass
//

import SwiftUI
import CoreData

struct CompareChipRowView: View {
    let destinations: [Destination]
    let onRemove: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(destinations, id: \.id) { destination in
                    chip(for: destination)
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(for destination: Destination) -> some View {
        HStack(spacing: 8) {
            avatar(for: destination)
            Text(destination.name ?? "Unknown")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppBrand.heading)
                .lineLimit(1)

            Button {
                guard let id = destination.id else { return }
                onRemove(id)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(destination.name ?? "destination")")
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .background(AppBrand.card, in: Capsule())
        .overlay(
            Capsule().stroke(Color(.separator), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func avatar(for destination: Destination) -> some View {
        if let url = destination.imageURL.flatMap(URL.init(string:)) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Color(.secondarySystemBackground)
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(AppBrand.accentTint)
                .frame(width: 28, height: 28)
                .overlay {
                    Text(String(destination.name?.prefix(1) ?? "?"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppBrand.accentStrong)
                }
        }
    }
}
