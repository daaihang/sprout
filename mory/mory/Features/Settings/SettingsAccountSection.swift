import AVFoundation
import Foundation
import Photos
import Speech
import SwiftUI
import UIKit

struct SettingsAccountSection: View {
    @Environment(\.localDataDiagnostics) private var localDataDiagnostics

    let authManager: AuthSessionManager?

    @State private var diagnostics: AuthDiagnosticsSnapshot?
    @State private var errorMessage: String?
    @State private var isConfirmingSignOut = false
    @State private var isSigningOut = false

    var body: some View {
        List {
            Section("settings.account.title") {
                if let diagnostics {
                    LabeledContent("settings.account.state", value: diagnostics.state)
                    LabeledContent("settings.account.userID", value: diagnostics.userID ?? String(localized: "settings.account.localUser"))
                    LabeledContent("Local data owner", value: diagnostics.localDataOwnerID ?? "None")
                    if let localDataDiagnostics {
                        LabeledContent("Local data scope", value: localDataDiagnostics.scopeLabel)
                        LabeledContent("Local data store", value: localDataDiagnostics.storeURLDescription)
                    }
                    LabeledContent("settings.account.guest", value: diagnostics.isGuest ? String(localized: "common.yes") : String(localized: "common.no"))
                } else {
                    ProgressView()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    isConfirmingSignOut = true
                } label: {
                    if isSigningOut {
                        ProgressView()
                    } else {
                        Label("settings.account.signOut", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                .disabled(authManager == nil || isSigningOut)
            }
        }
        .navigationTitle("settings.account.title")
        .task {
            await load()
        }
        .alert("settings.account.signOut.confirm.title", isPresented: $isConfirmingSignOut) {
            Button("common.cancel", role: .cancel) {}
            Button("settings.account.signOut", role: .destructive) {
                Task { await signOut() }
            }
        } message: {
            Text("settings.account.signOut.confirm.message")
        }
    }

    @MainActor
    private func load() async {
        guard let authManager else {
            errorMessage = String(localized: "settings.account.noManager")
            return
        }
        diagnostics = await authManager.fetchDiagnostics()
        errorMessage = nil
    }

    @MainActor
    private func signOut() async {
        guard let authManager else { return }
        isSigningOut = true
        defer { isSigningOut = false }
        await authManager.signOut()
        diagnostics = await authManager.fetchDiagnostics()
        errorMessage = nil
    }
}
