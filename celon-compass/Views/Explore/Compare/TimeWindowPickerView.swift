//
//  TimeWindowPickerView.swift
//  celon-compass
//

import SwiftUI

struct TimeWindowPickerView: View {
    @Binding var window: CompareWindow
    @State private var showingCustom = false
    @State private var customStart: Date = .now
    @State private var customEnd: Date = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now

    var body: some View {
        HStack(spacing: 8) {
            pill(for: .next5, isSelected: isSelected(.next5))
            pill(for: .next14, isSelected: isSelected(.next14))
            pill(for: .custom(start: customStart, end: customEnd), isSelected: isCustomSelected)
        }
        .padding(.horizontal)
        .sensoryFeedback(.selection, trigger: window)
        .sheet(isPresented: $showingCustom) {
            customRangeSheet
        }
    }

    private func isSelected(_ candidate: CompareWindow) -> Bool {
        switch (window, candidate) {
        case (.next5, .next5), (.next14, .next14): return true
        default: return false
        }
    }

    private var isCustomSelected: Bool {
        if case .custom = window { return true }
        return false
    }

    private func pill(for candidate: CompareWindow, isSelected: Bool) -> some View {
        Button {
            switch candidate {
            case .next5, .next14:
                window = candidate
            case .custom:
                showingCustom = true
            }
        } label: {
            Text(candidate.title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? AppBrand.card : Color.clear, in: Capsule())
                .foregroundStyle(isSelected ? AppBrand.navy : .secondary)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? AppBrand.tealTop.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var customRangeSheet: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start", selection: $customStart, in: ...horizonEnd, displayedComponents: .date)
                    DatePicker("End", selection: $customEnd, in: customStart...horizonEnd, displayedComponents: .date)
                } footer: {
                    Text("Open-Meteo returns up to \(ForecastHorizon.maximumDaysAhead) days from today.")
                }
            }
            .navigationTitle("Custom range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingCustom = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        window = .custom(start: customStart, end: customEnd)
                        showingCustom = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var horizonEnd: Date {
        Calendar.current.date(byAdding: .day, value: ForecastHorizon.maximumDaysAhead, to: .now) ?? .now
    }
}

#Preview {
    struct Host: View {
        @State var window: CompareWindow = .next5
        var body: some View {
            VStack(spacing: 24) {
                TimeWindowPickerView(window: $window)
                Text("Selected: \(window.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical)
            .background(AppBrand.canvas)
        }
    }
    return Host()
}
