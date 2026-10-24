//
//  AccountView.swift
//  celon-compass
//
//

import SwiftUI
import CoreData

struct AccountView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var alertTitle: String?
    @State private var alertMessage = ""

    private var linkedEmail: String? { AuthService.shared.linkedEmail }

    var body: some View {
        List {
            SettingsCard(
                title: "Sync",
                footer: linkedEmail == nil
                    ? "You're using \(AppBrand.name) as a guest. Linking an account to sync trips across devices is coming soon."
                    : nil
            ) {
                SettingsRow(
                    title: linkedEmail ?? "Guest",
                    subtitle: linkedEmail == nil ? "Trips are stored on this device only" : "Linked account",
                    icon: linkedEmail == nil ? "person.crop.circle" : "person.crop.circle.badge.checkmark"
                )
            }

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
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppBrand.canvas)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
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

    private func deleteAccount() {
        isDeleting = true
        Task {
            defer { isDeleting = false }
            do {
                try await AccountService(context: context).deleteAccount()
                alertTitle = "Account deleted"
                alertMessage = "Your data has been removed."
            } catch {
               
                if let message = DestructiveActionGuard.userMessage(for: error, noun: "your account") {
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
