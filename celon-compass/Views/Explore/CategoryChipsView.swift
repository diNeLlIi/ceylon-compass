//
//  CategoryChipsView.swift
//  celon-compass

import SwiftUI

struct CategoryChipsView: View {
    @Binding var selectedCategory: DestinationCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DestinationCategory.allCases) { category in
                    chip(for: category)
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(for category: DestinationCategory) -> some View {
        let isSelected = category == selectedCategory
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 6) {
                if let icon = category.iconName {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(category.rawValue)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? AppBrand.tealMid : Color(.secondarySystemBackground), in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selectedCategory)
    }
}

private extension DestinationCategory {
    var iconName: String? {
        switch self {
        case .all: return nil
        case .beach: return "beach.umbrella"
        case .mountain: return "mountain.2"
        case .heritage: return "building.columns"
        case .wildlife: return "pawprint"
        }
    }
}

#Preview {
    CategoryChipsView(selectedCategory: .constant(.beach))
}
