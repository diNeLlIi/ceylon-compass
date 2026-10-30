//
//  ExploreSidebarView.swift
//  celon-compass
//
//  Regular-width only. Binds to the same ExploreViewModel state as the compact chip row,
//  so a filter set here and a filter set there are the same filter.
//

import SwiftUI

struct ExploreSidebarView: View {
    @Binding var selectedCategory: DestinationCategory
    @Binding var selectedProvince: Province?
    let countForProvince: (Province) -> Int
    let matchCount: Int

    var body: some View {
        List {
            Section("Category") {
                ForEach(DestinationCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        row(title: category.rawValue, isSelected: category == selectedCategory)
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Province") {
                Button {
                    selectedProvince = nil
                } label: {
                    row(title: "All provinces", isSelected: selectedProvince == nil)
                }
                .buttonStyle(.plain)

                ForEach(Province.allCases) { province in
                    let count = countForProvince(province)
                    Button {
                        selectedProvince = province
                    } label: {
                        row(
                            title: province.displayName,
                            trailing: "\(count)",
                            isSelected: province == selectedProvince
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(count == 0 && selectedProvince != province)
                }
            }

            Section {
                Text("\(matchCount) \(matchCount == 1 ? "place" : "places")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Filters")
    }

    private func row(title: String, trailing: String? = nil, isSelected: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(isSelected ? AppBrand.accentStrong : AppBrand.heading)
                .fontWeight(isSelected ? .semibold : .regular)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(AppBrand.accentStrong)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationSplitView {
        ExploreSidebarView(
            selectedCategory: .constant(.all),
            selectedProvince: .constant(.southern),
            countForProvince: { _ in 3 },
            matchCount: 3
        )
    } detail: {
        Text("Detail")
    }
}
