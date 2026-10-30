//
//  SettingsView.swift
//  celon-compass
//

import SwiftUI
import StoreKit
import CoreData

struct SettingsView: View {
    @State private var model = SettingsViewModel()
    @State private var isConfirmingClear = false

    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                accountSection
                preferencesSection
                securitySection
                dataSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppBrand.canvas)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .brandToolbar()
            .task { await model.load() }
            .confirmationDialog(
                "Clear cached maps & photos?",
                isPresented: $isConfirmingClear,
                titleVisibility: .visible
            ) {
                Button("Clear Cache", role: .destructive) {
                    Task { await model.clearCache() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Offline maps and photos will be removed from this device. You'll be asked to verify it's you.")
            }
            .alert(item: $model.notice) { notice in
                Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
            }
            .alert("Notifications are off", isPresented: $model.isShowingNotificationsDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Not Now", role: .cancel) {}
            } message: {
                Text("Allow notifications for \(AppBrand.name) in the iOS Settings app to turn this on.")
            }
        }
    }


    private var accountSection: some View {
        SettingsCard(title: "Account") {
            NavigationLink {
                ProfileView()
            } label: {
                SettingsRow(
                    title: UserProfileStore.shared.displayName ?? (AuthService.shared.linkedEmail ?? "Guest"),
                    subtitle: AuthService.shared.isAnonymous ? "Tap to set up your account" : "Signed in",
                    icon: "person.crop.circle"
                )
            }
            .accessibilityIdentifier("settings.account")
        }
    }


//Preferences
    private var preferencesSection: some View {
        SettingsCard(title: "Preferences") {
            SettingsRow(title: "Home city") {
                TextField("Colombo", text: Binding(
                    get: { model.preferences.homeCity },
                    set: { model.preferences.homeCity = $0 }
                ))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("settings.homeCity")

            NavigationLink {
                EditInterestsView(preferences: model.preferences)
            } label: {
                SettingsRow(title: "Interests", subtitle: interestsSummary)
            }
            .accessibilityIdentifier("settings.interests")

            SettingsRow(title: "Temperature") {
                UnitToggle(selection: Binding(
                    get: { model.preferences.temperatureUnit },
                    set: { model.preferences.temperatureUnit = $0 }
                ))
            }

            SettingsRow(title: "Appearance") {
                Picker("Appearance", selection: Binding(
                    get: { model.preferences.appearanceMode },
                    set: { model.preferences.appearanceMode = $0 }
                )) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.name).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .accessibilityIdentifier("settings.appearance")

            SettingsRow(title: "Rain tolerance") {
                Picker("Rain tolerance", selection: Binding(
                    get: { model.preferences.rainTolerance },
                    set: { model.preferences.rainTolerance = $0 }
                )) {
                    ForEach(RainTolerance.allCases) { level in
                        Text(level.rawValue.capitalized).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .accessibilityIdentifier("settings.rainTolerance")

            Toggle("Weather alerts", isOn: Binding(
                get: { model.preferences.weatherAlertsEnabled },
                set: { value in Task { await model.setWeatherAlerts(value) } }
            ))
            .tint(AppBrand.success)
            .accessibilityIdentifier("settings.weatherAlerts")

            Toggle("Trip reminders", isOn: Binding(
                get: { model.preferences.tripRemindersEnabled },
                set: { value in Task { await model.setTripReminders(value) } }
            ))
            .tint(AppBrand.success)
            .accessibilityIdentifier("settings.tripReminders")
        }
    }

    private var interestsSummary: String {
        let sorted = model.preferences.interests
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.rawValue)
        if sorted.isEmpty { return "None selected" }
        if sorted.count <= 3 { return sorted.joined(separator: ", ") }
        return "\(sorted.prefix(2).joined(separator: ", ")) +\(sorted.count - 2) more"
    }

//user data
    private var securitySection: some View {
        SettingsCard(title: "Security") {
            NavigationLink {
                SecurityView()
            } label: {
                SettingsRow(title: "App Lock", subtitle: PreferencesStore.shared.faceIDLockEnabled ? "On" : "Off")
            }
            .accessibilityIdentifier("settings.security")
        }
    }

//user data
    private var dataSection: some View {
        SettingsCard(
            title: "Data & Sync",
            footer: model.cacheSize > 0
                ? "Clearing removes \(model.cacheSizeText) of offline maps. Your trips and memories stay on device."
                : "No offline maps or photos are stored. Your trips and memories stay on device."
        ) {
            SettingsRow(title: "Last synced") {
                Text(model.lastSyncedText)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await model.refreshDestinations() }
            } label: {
                SettingsRow(
                    title: "Refresh destinations",
                    icon: "arrow.clockwise",
                    tint: AppBrand.link,
                    showsChevron: !model.isRefreshing
                ) {
                    if model.isRefreshing { ProgressView() }
                }
            }
            .disabled(model.isRefreshing)
            .accessibilityIdentifier("settings.refresh")

            Button {
                isConfirmingClear = true
            } label: {
                SettingsRow(
                    title: "Clear cache",
                    icon: "trash",
                    tint: AppBrand.destructive
                ) {
                    BiometricBadge(kind: model.biometry)
                }
            }
            .disabled(!model.canClearCache)
            .accessibilityIdentifier("settings.clearCache")
        }
    }

    
    

    private var aboutSection: some View {
        SettingsCard(
            title: "About",
            footer: "Weather data from the Department of Meteorology, Sri Lanka. Places via OpenStreetMap contributors."
        ) {
            SettingsRow(title: "Version") {
                Text(versionText).foregroundStyle(.secondary)
            }

            Button {
                requestReview()
            } label: {
                SettingsRow(title: "Rate \(AppBrand.name)", showsChevron: true)
            }
            .accessibilityIdentifier("settings.rate")

            if let privacyURL = AppBrand.privacyPolicyURL {
                Button {
                    openURL(privacyURL)
                } label: {
                    SettingsRow(title: "Privacy policy", showsChevron: true)
                }
                .accessibilityIdentifier("settings.privacy")
            }

            #if DEBUG
            Button {
                PreferencesStore.shared.hasOnboarded = false
            } label: {
                SettingsRow(title: "Reset onboarding", icon: "arrow.counterclockwise", tint: .orange)
            }
            .accessibilityIdentifier("settings.resetOnboarding")
            #endif
        }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
