//
//  SettingsView.swift
//  celon-compass
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var alertTitle: String?
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Security") {
                    let biometry = BiometricService.shared.biometryKind
                    Label("Unlock with \(biometry.title)", systemImage: biometry.symbolName)
                }

                Section {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                    }
                    .disabled(isDeleting)
                    .accessibilityIdentifier("settings.deleteAccount")
                } footer: {
                    Text("Removes your trips and notes from this device and deletes your account. You'll be asked to verify it's you.")
                }

                Section("About") {
                    LabeledContent("App", value: AppBrand.name)
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
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
                // A plain cancel returns nil: nothing was deleted, nothing to report
                if let message = DestructiveActionGuard.userMessage(for: error, noun: "your account") {
                    alertTitle = "Account not deleted"
                    alertMessage = message
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
