//
//  AccountView.swift
//  celon-compass
//

import SwiftUI
import CoreData

struct AccountView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var alertTitle: String?
    @State private var alertMessage = ""
    @State private var showAuthFlow = false
    @State private var showSignOutConfirm = false
    @State private var authModel = AuthViewModel()
    @State private var reauthPassword = ""
    @State private var showReauthSheet = false

    private var linkedEmail: String? { AuthService.shared.linkedEmail }
    private var isGuest: Bool { AuthService.shared.isAnonymous }

    var body: some View {
        List {
            if isGuest {
                guestSection
            } else {
                signedInSection
            }
            dangerZone
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppBrand.canvas)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
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

    //Guest state

    private var guestSection: some View {
        SettingsCard(
            title: "Sync your trips",
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
                SettingsRow(title: "Sign in", icon: "person.crop.circle", tint: AppBrand.link, showsChevron: true)
            }
            .accessibilityIdentifier("account.signIn")
        }
    }

    
    //Signed in state

    private var signedInSection: some View {
        SettingsCard(title: "Account") {
            SettingsRow(
                title: linkedEmail ?? "Signed in",
                subtitle: "Linked account",
                icon: "person.crop.circle.badge.checkmark"
            )

            Button {
                showSignOutConfirm = true
            } label: {
                SettingsRow(title: "Sign out", icon: "rectangle.portrait.and.arrow.right", tint: .secondary)
            }
            .accessibilityIdentifier("account.signOut")
        }
    }

    
    //Danger zone

    private var dangerZone: some View {
        SettingsCard(
            title: "Danger zone",
            footer: "Removes your trips and notes from this device and deletes your account. You'll be asked to verify it's you."
        ) {
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                SettingsRow(
                    title: "Delete Account",
                    icon: "person.crop.circle.badge.minus",
                    tint: AppBrand.destructive
                )
            }
            .disabled(isDeleting)
            .accessibilityIdentifier("settings.deleteAccount")
        }
    }

    
    //Helpers

    private var tripCount: Int {
        (try? context.count(for: Itinerary.fetchRequest())) ?? 0
    }

    private var memoryCount: Int {
        (try? context.count(for: VisitRecord.fetchRequest())) ?? 0
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
                    showReauthSheet = true
                } else if let message = DestructiveActionGuard.userMessage(for: error, noun: "your account") {
                    alertTitle = "Account not deleted"
                    alertMessage = message
                }
            }
        }
    }
}

#Preview {
    NavigationStack { AccountView() }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
