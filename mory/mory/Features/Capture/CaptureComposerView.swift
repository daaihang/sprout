import SwiftData
import SwiftUI

struct CaptureComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var bodyText = ""
    @State private var mood = ""
    @State private var inputContext = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var onSaved: (() -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Everything saved here is local-first. This is the first stable path into the new memory stack.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Capture") {
                    TextField("Title", text: $title)
                    TextField("What happened?", text: $bodyText, axis: .vertical)
                        .lineLimit(4...10)
                }

                Section("Context") {
                    TextField("Mood", text: $mood)
                    TextField("Input Context", text: $inputContext, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("New Memory")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || normalizedCaptureText == nil)
                }
            }
        }
    }

    private var normalizedTitle: String? {
        title.trimmedOrNil ?? bodyText.firstMeaningfulLine
    }

    private var normalizedCaptureText: String? {
        bodyText.trimmedOrNil ?? title.trimmedOrNil
    }

    private func save() async {
        guard !isSaving, let rawText = normalizedCaptureText else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let repository = MoryMemoryRepository(modelContext: modelContext)
            let now = Date.now
            let recordID = UUID()
            let artifactTitle = normalizedTitle ?? "Untitled Memory"
            let artifactSummary = bodyText.trimmedOrNil ?? rawText
            let artifact = Artifact(
                recordID: recordID,
                kind: .text,
                title: artifactTitle,
                summary: artifactSummary,
                textContent: rawText,
                payload: .text(rawText),
                metadata: [:],
                createdAt: now,
                updatedAt: now
            )

            let recordShell = RecordShell(
                id: recordID,
                createdAt: now,
                updatedAt: now,
                captureSource: .composer,
                rawText: rawText,
                userMood: mood.trimmedOrNil,
                userIntensity: nil,
                inputContext: inputContext.trimmedOrNil,
                artifactIDs: [artifact.id]
            )

            try repository.upsert(recordShell: recordShell)
            try repository.upsert(artifact: artifact)
            try repository.save()

            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var trimmedOrNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var firstMeaningfulLine: String? {
        split(whereSeparator: { $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }
}
