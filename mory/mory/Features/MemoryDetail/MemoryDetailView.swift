import SwiftUI

struct MemoryDetailView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let recordID: UUID

    @State private var snapshot: MemoryDetailSnapshot?
    @State private var userPreference = UserSettingsPreference.defaults
    @State private var recordPreference: MemoryDetailPresentationPreference?
    @State private var errorMessage: String?
    @State private var isRefreshingPipeline = false
    @State private var isReloading = false
    @State private var isEditing = false
    @State private var draftRawText = ""
    @State private var draftMood = ""
    @State private var draftInputContext = ""
    @State private var draftArtifactText = ""
    @State private var isSavingEdits = false

    private let resolver = MemoryDetailPresentationResolver()

    private var presentation: MemoryDetailPresentationSnapshot? {
        guard let snapshot else { return nil }
        return resolver.resolve(
            snapshot: snapshot,
            userPreference: userPreference,
            recordPreference: recordPreference
        )
    }

    var body: some View {
        Group {
            if let presentation {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        MemoryDetailAdaptiveView(presentation: presentation)
                        MemoryDetailInsightPanel(presentation: presentation)
                    }
                    .padding(.vertical, 18)
                }
                .background(Color(.systemBackground))
            } else if let errorMessage {
                ContentUnavailableView(
                    "memory.error.notFound",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .moryHidesTabChrome()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("memory.edit.button") {
                        prepareEditDraft()
                        isEditing = true
                    }

                    Button(isRefreshingPipeline ? String(localized: "memory.analysis.retrying") : String(localized: "memory.analysis.retry")) {
                        Task { await refreshPipeline() }
                    }
                    .disabled(isRefreshingPipeline)

                    Divider()

                    Button {
                        clearPresentationMode()
                    } label: {
                        Label("Automatic layout", systemImage: recordPreference == nil ? "checkmark" : "wand.and.stars")
                    }

                    ForEach(MemoryDetailPresentationMode.allCases) { mode in
                        Button {
                            savePresentationMode(mode)
                        } label: {
                            Label(mode.title, systemImage: recordPreference?.mode == mode ? "checkmark" : mode.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("common.more")
            }
        }
        .task(id: recordID) {
            await load()
        }
        .refreshable {
            await load()
        }
        .sheet(isPresented: $isEditing) {
            editSheet
        }
        .onReceive(NotificationCenter.default.publisher(for: .pipelineDidComplete)) { notification in
            if let id = notification.userInfo?["recordID"] as? UUID, id == recordID {
                Task { await load() }
            }
        }
    }

    private var editSheet: some View {
        NavigationStack {
            Form {
                Section("memory.section.record") {
                    TextField("memory.label.rawCapture", text: $draftRawText, axis: .vertical)
                        .lineLimit(5...14)
                    TextField("memory.label.mood", text: $draftMood)
                    TextField("memory.label.context", text: $draftInputContext, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("memory.section.attachments") {
                    TextField("memory.edit.addAttachment", text: $draftArtifactText, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("memory.edit.button")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("memory.edit.cancel") {
                        isEditing = false
                    }
                    .disabled(isSavingEdits)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSavingEdits ? String(localized: "common.saving") : String(localized: "memory.edit.saveChanges")) {
                        Task { await saveEdits() }
                    }
                    .disabled(isSavingEdits || draftRawText.trimmedOrNil == nil)
                }
            }
        }
    }

    @MainActor
    private func load() async {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }

        do {
            snapshot = try memoryRepository.fetchMemoryDetail(recordID: recordID)
            userPreference = try memoryRepository.fetchUserSettingsPreference()
            recordPreference = try memoryRepository.fetchMemoryDetailPresentationPreference(recordID: recordID)
            if let snapshot {
                resetEditDraft(from: snapshot.record)
            }
            errorMessage = snapshot == nil ? String(localized: "memory.error.notFound") : nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshPipeline() async {
        guard !isRefreshingPipeline else { return }
        isRefreshingPipeline = true
        defer { isRefreshingPipeline = false }
        do {
            try await memoryRepository.refreshMemoryPipeline(recordID: recordID)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }

    private func prepareEditDraft() {
        if let record = snapshot?.record {
            resetEditDraft(from: record)
        }
    }

    private func resetEditDraft(from record: RecordShell) {
        draftRawText = record.rawText
        draftMood = record.userMood ?? ""
        draftInputContext = record.inputContext ?? ""
        draftArtifactText = ""
    }

    @MainActor
    private func saveEdits() async {
        guard !isSavingEdits else { return }
        isSavingEdits = true
        defer { isSavingEdits = false }

        do {
            snapshot = try await memoryRepository.updateMemory(
                recordID: recordID,
                draft: MemoryEditDraft(
                    rawText: draftRawText,
                    userMood: draftMood.trimmedOrNil,
                    inputContext: draftInputContext.trimmedOrNil,
                    appendedArtifactText: draftArtifactText.trimmedOrNil
                )
            )
            isEditing = false
            errorMessage = nil
            try await memoryRepository.refreshMemoryPipeline(recordID: recordID)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }

    private func savePresentationMode(_ mode: MemoryDetailPresentationMode) {
        do {
            let preference = MemoryDetailPresentationPreference(recordID: recordID, mode: mode)
            try memoryRepository.saveMemoryDetailPresentationPreference(preference)
            recordPreference = preference
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearPresentationMode() {
        do {
            try memoryRepository.clearMemoryDetailPresentationPreference(recordID: recordID)
            recordPreference = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
