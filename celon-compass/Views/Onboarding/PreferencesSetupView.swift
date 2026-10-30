//
//  PreferencesSetupView.swift
//  celon-compass
//

import SwiftUI

struct PreferencesSetupView: View {
    @State private var homeCity: String = "Colombo"
    @State private var selectedInterests: Set<TravelInterest> = []
    @State private var temperatureUnit: TemperatureUnit = .celsius
    var onFinish: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            AppBrand.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                preferencesCard
                Spacer()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrandHeader(surface: .onBrand)

            Text("Set up your trip preferences")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)

            progressBar
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(AppBrand.navy)
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppBrand.amber)
                    .frame(height: 4)
            }
        }
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            homeCityField
            interestChips
            temperatureRow
            startButton
        }
        .padding(20)
        .background(AppBrand.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    private var homeCityField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Home city")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "location")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                TextField("Colombo", text: $homeCity)
                    .font(.system(size: 16))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Color(.systemGray6),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
    }

    private var interestChips: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What interests you?")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(TravelInterest.allCases) { interest in
                    let isSelected = selectedInterests.contains(interest)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isSelected {
                                selectedInterests.remove(interest)
                            } else {
                                selectedInterests.insert(interest)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: interest.symbolName)
                                .font(.system(size: 13))
                            Text(interest.rawValue)
                                .font(.system(size: 15, weight: .semibold))
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
        }
    }

    private var temperatureRow: some View {
        HStack {
            Text("Temperature unit")
                .font(.system(size: 15, weight: .medium))
            Spacer()
            UnitToggle(selection: $temperatureUnit)
        }
    }

    private var startButton: some View {
        Button(action: save) {
            Text("Start exploring")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(AppBrand.tealTop, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.top, 4)
    }

    private func save() {
        let prefs = PreferencesStore.shared
        prefs.homeCity = homeCity.trimmingCharacters(in: .whitespaces)
        prefs.interests = selectedInterests
        prefs.temperatureUnit = temperatureUnit
        prefs.hasOnboarded = true
        onFinish()
    }
}

#Preview {
    PreferencesSetupView(onFinish: {})
}
