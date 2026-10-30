//
//  DestinationSearchBar.swift
//  celon-compass
//
//  The search field from Explore, factored out so My Trips and the Map use the same one.

import SwiftUI

struct DestinationSearchBar: View {
    @Binding var text: String
    var prompt: String = "Search destinations"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(.secondary))
                .font(.body)
                .foregroundStyle(.primary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(AppBrand.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

// Compact result row: enough to tell two destinations apart without opening either.
struct DestinationSearchRow: View {
    let destination: Destination

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(destination.name ?? "Destination")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppBrand.heading)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        [destination.category, destination.province]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = destination.imageURL.flatMap(URL.init(string:)) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    AppBrand.cardHighlight
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppBrand.cardHighlight)
                .frame(width: 44, height: 44)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        DestinationSearchBar(text: .constant(""))
        DestinationSearchBar(text: .constant("Ella"))
    }
    .padding()
    .background(AppBrand.canvas)
}
