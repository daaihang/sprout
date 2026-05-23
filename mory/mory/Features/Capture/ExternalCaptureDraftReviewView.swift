import SwiftUI

struct ExternalCaptureDraftReviewView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var sourceKind: ExternalCaptureSourceKind = .appIntent
    @State private var title = ""
    @State private var text = ""
    @State private var url = ""
    @State private var context = ""
    @State private var affectLabelRaw = ""
    @State private var toneHintRaw = ""
    @State private var previewDraft: MemoryCaptureDraft?
    @State private var inboxItems: [ExternalCaptureInboxItem] = []
    @State private var message: String?
    @State private var isSaving = false

    private let draftFactory = ExternalCaptureDraftFactory()
    private let inboxCodec = ExternalCaptureInboxCodec()

    var body: some View {
        Form {
            Section("Pending Inbox") {
                if inboxItems.isEmpty {
                    Text("No external captures.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(inboxItems) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title ?? item.sourceKind.rawValue)
                                        .font(.headline)
                                    Text(item.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    Text("\(item.sourceKind.rawValue) • \(item.status.rawValue)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            HStack {
                                Button("Preview") {
                                    previewInboxItem(item)
                                }
                                Button("Import") {
                                    Task { await importInboxItem(item) }
                                }
                                .disabled(item.status != .pending || isSaving)
                                Button("Dismiss") {
                                    dismissInboxItem(item)
                                }
                                .disabled(item.status != .pending || isSaving)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Section("Input") {
                Picker("Source", selection: $sourceKind) {
                    ForEach(ExternalCaptureSourceKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                TextField("Title", text: $title)
                TextField("Text", text: $text, axis: .vertical)
                    .lineLimit(2...4)
                TextField("URL", text: $url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Context", text: $context)
                TextField("Affect label (optional)", text: $affectLabelRaw)
                TextField("Tone hint (optional)", text: $toneHintRaw)
            }

            Section {
                Button("Build Draft Preview") {
                    previewDraft = buildDraft()
                    message = "Draft preview updated."
                }
                Button("Queue As Pending Inbox Item") {
                    queueCurrentRequest()
                }
                Button("Create Memory From Preview") {
                    Task { await createMemoryFromPreview() }
                }
                .disabled(previewDraft == nil || isSaving)
            }

            if let draft = previewDraft {
                Section("Draft Preview") {
                    LabeledContent("Title", value: draft.title ?? "none")
                    LabeledContent("Raw text", value: draft.rawText)
                    LabeledContent("Mood", value: draft.mood ?? "none")
                    LabeledContent("Context", value: draft.inputContext ?? "none")
                    LabeledContent("Capture source", value: draft.captureSource.rawValue)
                    LabeledContent("Artifacts", value: "\(draft.artifacts.count)")
                    LabeledContent("Affect snapshots", value: "\(draft.affectSnapshots.count)")
                }
            }

            if let message {
                Section("Status") {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("External Capture")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            previewDraft = buildDraft()
            loadInbox()
        }
    }

    private func buildDraft() -> MemoryCaptureDraft {
        draftFactory.makeDraft(from: buildRequest())
    }

    private func buildRequest() -> ExternalCaptureRequest {
        let trimmedText = text.trimmedOrNil ?? "Draft imported from external capture shell."
        let label = AffectLabel(rawValue: affectLabelRaw.trimmingCharacters(in: .whitespacesAndNewlines))
        let tone = ToneHint(rawValue: toneHintRaw.trimmingCharacters(in: .whitespacesAndNewlines))
        let affectEvidence = ExternalCaptureAffectEvidence(
            source: .userSelected,
            label: label?.rawValue,
            labels: label.map { [$0.rawValue] } ?? [],
            toneHints: tone.map { [$0.rawValue] } ?? [],
            rawInput: label?.rawValue,
            confidence: 1,
            userConfirmed: true
        )
        return ExternalCaptureRequest(
            sourceKind: sourceKind,
            title: title.trimmedOrNil,
            text: trimmedText,
            url: url.trimmedOrNil,
            context: context.trimmedOrNil,
            evidenceItems: url.trimmedOrNil.map {
                [ExternalCaptureEvidenceItem(kind: .link, title: title.trimmedOrNil, value: $0, metadata: ["url": $0])]
            } ?? [],
            affectEvidence: (label == nil && tone == nil) ? [] : [affectEvidence]
        )
    }

    private func loadInbox() {
        do {
            inboxItems = try memoryRepository.fetchExternalCaptureInbox(status: nil, limit: 20)
        } catch {
            message = error.localizedDescription
        }
    }

    private func queueCurrentRequest() {
        do {
            _ = try memoryRepository.enqueueExternalCapture(buildRequest(), receivedAt: .now)
            message = "Queued external capture."
            loadInbox()
        } catch {
            message = error.localizedDescription
        }
    }

    private func previewInboxItem(_ item: ExternalCaptureInboxItem) {
        do {
            previewDraft = try inboxCodec.makeDraft(from: item)
            message = "Loaded inbox item preview."
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func importInboxItem(_ item: ExternalCaptureInboxItem) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await memoryRepository.createMemoryFromExternalCaptureInboxItem(item.id)
            message = "Imported memory \(saved.id.uuidString.prefix(8))."
            loadInbox()
        } catch {
            message = error.localizedDescription
        }
    }

    private func dismissInboxItem(_ item: ExternalCaptureInboxItem) {
        do {
            try memoryRepository.dismissExternalCaptureInboxItem(item.id)
            message = "Dismissed external capture."
            loadInbox()
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func createMemoryFromPreview() async {
        guard let previewDraft else {
            message = "Build preview first."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await memoryRepository.createMemory(from: previewDraft)
            message = "Created memory \(saved.id.uuidString.prefix(8))."
        } catch {
            message = error.localizedDescription
        }
    }
}
