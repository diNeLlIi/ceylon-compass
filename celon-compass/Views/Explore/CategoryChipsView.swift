//
//  CategoryChipsView.swift
//  celon-compass
//

import SwiftUI

struct CategoryChipsView: View {
    @Binding var selectedCategory: DestinationCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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
            selectedCategory = category
        } label: {
            Text(category.rawValue)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppBrand.tealMid : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CategoryChipsView(selectedCategory: .constant(.beach))
}
