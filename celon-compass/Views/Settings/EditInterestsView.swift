//
//  EditInterestsView.swift
//  celon-compass
//

import SwiftUI

struct EditInterestsView: View {
    var preferences: PreferencesStore

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(TravelInterest.allCases) { interest in
                        let isSelected = preferences.interests.contains(interest)
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if isSelected {
                                    preferences.interests.remove(interest)
                                } else {
                                    preferences.interests.insert(interest)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: interest.symbolName)
                                    .font(.system(size: 13))
                                Text(interest.rawValue)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                isSelected ? AppBrand.tealTop : Color.clear,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        isSelected ? Color.clear : Color(.systemGray4),
                                        lineWidth: 1
                                    )
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: isSelected)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(AppBrand.card)
            } header: {
                Text("What interests you?")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
            } footer: {
                Text("Your interests help personalise destination recommendations.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppBrand.canvas)
        .navigationTitle("Interests")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        EditInterestsView(preferences: PreferencesStore.shared)
    }
}
