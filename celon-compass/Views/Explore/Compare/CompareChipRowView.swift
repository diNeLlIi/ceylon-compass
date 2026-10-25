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
        HStack(spacing: 6) {
            Circle()
                .fill(AppBrand.tealTop.opacity(0.25))
                .frame(width: 22, height: 22)
                .overlay {
                    Text(String(destination.name?.prefix(1) ?? "?"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppBrand.tealMid)
                }

            Text(destination.name ?? "Unknown")
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            Button {
                guard let id = destination.id else { return }
                onRemove(id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground), in: Capsule())
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let a = Destination(context: context)
    a.id = UUID()
    a.name = "Ella"
    let b = Destination(context: context)
    b.id = UUID()
    b.name = "Mirissa"

    return CompareChipRowView(destinations: [a, b], onRemove: { _ in })
}
