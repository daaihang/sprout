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
    @State private var message: String?
    @State private var isSaving = false

    private let draftFactory = ExternalCaptureDraftFactory()

    var body: some View {
        Form {
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
        }
    }

    private func buildDraft() -> MemoryCaptureDraft {
        let trimmedText = text.trimmedOrNil ?? "Draft imported from external capture shell."
        let label = AffectLabel(rawValue: affectLabelRaw.trimmingCharacters(in: .whitespacesAndNewlines))
        let tone = ToneHint(rawValue: toneHintRaw.trimmingCharacters(in: .whitespacesAndNewlines))
        let affectDraft = AffectSnapshotDraft(
            labels: label.map { [$0] } ?? [],
            toneHints: tone.map { [$0] } ?? [],
            sources: [.userSelected],
            confidence: 1,
            evidenceSummary: "External capture local shell input",
            userConfirmed: true,
            rawInput: label?.rawValue
        )
        let request = ExternalCaptureRequest(
            sourceKind: sourceKind,
            title: title.trimmedOrNil,
            text: trimmedText,
            url: url.trimmedOrNil,
            context: context.trimmedOrNil,
            affectDrafts: (label == nil && tone == nil) ? [] : [affectDraft]
        )
        return draftFactory.makeDraft(from: request)
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
