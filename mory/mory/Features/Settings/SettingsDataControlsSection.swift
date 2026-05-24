import AVFoundation
import Foundation
import Photos
import Speech
import SwiftUI
import UIKit

struct SettingsDataControlsSection: View {
    let memoryRepository: any MoryMemoryRepositorying

    @State private var exportURL: URL?
    @State private var exportSummary: String?
    @State private var isExporting = false
    @State private var isDeleting = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("settings.data.export.section") {
                Text("settings.data.export.body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await exportLocalData() }
                } label: {
                    if isExporting {
                        ProgressView()
                    } else {
                        Label("settings.data.export.action", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(isExporting || isDeleting)

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("settings.data.export.share", systemImage: "square.and.arrow.up.on.square")
                    }
                }

                if let exportSummary {
                    Text(exportSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("settings.data.delete.body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Label("settings.data.delete.action", systemImage: "trash")
                    }
                }
                .disabled(isDeleting || isExporting)
            } header: {
                Text("settings.data.delete.section")
            } footer: {
                Text("settings.data.delete.footer")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("settings.data.title")
        .alert("settings.data.delete.confirm.title", isPresented: $isConfirmingDelete) {
            Button("common.cancel", role: .cancel) {}
            Button("settings.data.delete.confirm.action", role: .destructive) {
                Task { await deleteLocalData() }
            }
        } message: {
            Text("settings.data.delete.confirm.message")
        }
    }

    @MainActor
    private func exportLocalData() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let snapshot = try SettingsLocalDataExportSnapshot.make(repository: memoryRepository)
            let data = try snapshot.encodedData()
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mory-exports", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
            let timestamp = formatter.string(from: snapshot.exportedAt)
                .replacingOccurrences(of: ":", with: "-")
            let fileURL = directory.appendingPathComponent("mory-local-export-\(timestamp).json")
            try data.write(to: fileURL, options: [.atomic])
            exportURL = fileURL
            exportSummary = String(
                format: String(localized: "settings.data.export.summary.format"),
                snapshot.memories.count,
                snapshot.temporalArcs.count,
                snapshot.reflections.count
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteLocalData() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            try memoryRepository.clearAllLocalData()
            exportURL = nil
            exportSummary = String(localized: "settings.data.delete.completed")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

