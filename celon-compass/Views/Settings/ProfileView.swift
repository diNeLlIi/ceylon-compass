//
//  ProfileView.swift
//  celon-compass
//
//  Unified account & profile: identity, stats, account actions.
//

import SwiftUI
import CoreData

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var stats = ProfileStats()
    @State private var showAuthFlow = false
    @State private var showSignOutConfirm = false
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var alertTitle: String?
    @State private var alertMessage = ""
    @State private var authModel = AuthViewModel()

    private var store: UserProfileStore { .shared }
    private var isGuest: Bool { AuthService.shared.isAnonymous }
    private var linkedEmail: String? { AuthService.shared.linkedEmail }

    var body: some View {
        List {
            headerSection
            statsSection
            if isGuest {
                guestAccountSection
            } else {
                signedInAccountSection
            }
            dangerZoneSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppBrand.canvas)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .task { stats = loadStats() }
        .sheet(isPresented: $showAuthFlow) {
            AuthFlowView()
        }
        .confirmationDialog(
            "Sign out?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign Out") {
                Task { await authModel.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your trips stay synced to your account. You can sign back in anytime.")
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your trips and notes. It can't be undone.")
        }
        .alert(
            alertTitle ?? "",
            isPresented: Binding(
                get: { alertTitle != nil },
                set: { if !$0 { alertTitle = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    
    //Header

    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: isGuest ? "person.crop.circle.badge.questionmark" : "person.crop.circle.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundStyle(isGuest ? .secondary : AppBrand.accent)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 4) {
                    Text(store.displayName ?? (linkedEmail ?? "Guest"))
                        .font(.title3.weight(.semibold))

                    if let email = linkedEmail {
                        Text(email)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No account linked")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(AppBrand.card)
        }
    }

    
    //Stats

    private var statsSection: some View {
        SettingsCard(title: "Your activity") {
            HStack(spacing: 0) {
                statItem(value: stats.totalTrips, label: "Trips")
                Divider().frame(height: 32)
                statItem(value: stats.completedTrips, label: "Completed")
                Divider().frame(height: 32)
                statItem(value: stats.placesVisited, label: "Places")
                Divider().frame(height: 32)
                statItem(value: stats.memories, label: "Memories")
            }
            .padding(.vertical, 4)
        }
    }

    private func statItem(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    
    //Guest account

    private var guestAccountSection: some View {
        SettingsCard(
            title: "Account",
            footer: "\(tripCount) trips and \(memoryCount) memories are saved on this device only. Create an account to keep them safe."
        ) {
            Button {
                authModel.screen = .createAccount
                showAuthFlow = true
            } label: {
                SettingsRow(title: "Create account", icon: "person.crop.circle.badge.plus", tint: AppBrand.link, showsChevron: true)
            }
            .accessibilityIdentifier("account.create")

            Button {
                authModel.screen = .signIn
                showAuthFlow = true
            } label: {
                SettingsRow(title: "Sign in", icon: "arrow.right.circle", tint: AppBrand.link, showsChevron: true)
            }
            .accessibilityIdentifier("account.signIn")
        }
    }

    //Signed-in account

    private var signedInAccountSection: some View {
        SettingsCard(title: "Account") {
            Button {
                showSignOutConfirm = true
            } label: {
                SettingsRow(title: "Sign out", icon: "rectangle.portrait.and.arrow.right", tint: .secondary)
            }
            .accessibilityIdentifier("account.signOut")
        }
    }

    
    //Danger zone

    private var dangerZoneSection: some View {
        SettingsCard(
            title: "Danger zone",
            footer: "Removes your trips and notes from this device and deletes your account."
        ) {
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                SettingsRow(
                    title: "Delete account",
                    icon: "person.crop.circle.badge.minus",
                    tint: AppBrand.destructive
                )
            }
            .disabled(isDeleting)
            .accessibilityIdentifier("settings.deleteAccount")
        }
    }

    
    //Stats helpers

    private struct ProfileStats {
        var totalTrips = 0
        var completedTrips = 0
        var placesVisited = 0
        var memories = 0
    }

    private var tripCount: Int {
        (try? context.count(for: Itinerary.fetchRequest())) ?? 0
    }

    private var memoryCount: Int {
        (try? context.count(for: VisitRecord.fetchRequest())) ?? 0
    }

    private func loadStats() -> ProfileStats {
        let tripRequest = Itinerary.fetchRequest()
        let allTrips = (try? context.fetch(tripRequest)) ?? []
        let completed = allTrips.filter { $0.isCompleted }.count

        let visitCount = (try? context.count(for: VisitRecord.fetchRequest())) ?? 0

        let destRequest = NSFetchRequest<NSDictionary>(entityName: "VisitRecord")
        destRequest.resultType = .dictionaryResultType
        destRequest.propertiesToFetch = ["destination"]
        destRequest.returnsDistinctResults = true
        let uniquePlaces = (try? context.count(for: destRequest)) ?? 0

        return ProfileStats(
            totalTrips: allTrips.count,
            completedTrips: completed,
            placesVisited: uniquePlaces,
            memories: visitCount
        )
    }

    private func deleteAccount() {
        isDeleting = true
        Task {
            defer { isDeleting = false }
            do {
                try await AccountService(context: context).deleteAccount()
                alertTitle = "Account deleted"
                alertMessage = "Your data has been removed."
            } catch {
                if let failure = error as? AuthFailure, failure == .requiresRecentLogin {
                    // Could prompt re-auth here
                    alertTitle = "Session expired"
                    alertMessage = "Please sign in again to delete your account."
                } else if let message = DestructiveActionGuard.userMessage(for: error, noun: "your account") {
                    alertTitle = "Account not deleted"
                    alertMessage = message
                }
            }
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
