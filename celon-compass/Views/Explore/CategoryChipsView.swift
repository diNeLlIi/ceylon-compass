//
//  CategoryChipsView.swift
//  celon-compass

import SwiftUI

struct CategoryChipsView: View {
    @Binding var selectedCategory: DestinationCategory
    @Binding var selectedProvince: Province?
    // Supplied by the view model so the counts reflect the category and search already
    // in force, not the raw catalog.
    var countForProvince: (Province) -> Int = { _ in 0 }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                provinceChip
                ForEach(DestinationCategory.allCases) { category in
                    chip(for: category)
                }
            }
            .padding(.horizontal)
        }
    }

    // A menu rather than 9 more chips: the row is already horizontally scrolled, and
    // 9 extra capsules would bury the category chips the user reaches for most.
    private var provinceChip: some View {
        let isSelected = selectedProvince != nil
        return Menu {
            Button {
                selectedProvince = nil
            } label: {
                Label("All provinces", systemImage: selectedProvince == nil ? "checkmark" : "")
            }
            Divider()
            ForEach(Province.allCases) { province in
                let count = countForProvince(province)
                Button {
                    selectedProvince = province
                } label: {
                    Text(province.displayName)
                }
                // Shown-but-disabled rather than hidden: the catalog covers 5 of 9
                // provinces, and a user who can't see the other 4 can't tell whether
                // they're unsupported or merely empty.
                .disabled(count == 0 && selectedProvince != province)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "map")
                    .font(.caption)
                Text(selectedProvince?.displayName ?? "All provinces")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? AppBrand.tealMid : Color(.secondarySystemBackground), in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Province filter")
        .accessibilityValue(selectedProvince.map { "\($0.displayName) selected" } ?? "All provinces")
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
    CategoryChipsView(
        selectedCategory: .constant(.beach),
        selectedProvince: .constant(.southern),
        countForProvince: { _ in 3 }
    )
}
