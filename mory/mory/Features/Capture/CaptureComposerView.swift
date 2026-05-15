import SwiftUI

struct CaptureComposerView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.dismiss) private var dismiss

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
            let draft = MemoryCaptureDraft(
                title: normalizedTitle,
                rawText: rawText,
                mood: mood.trimmedOrNil,
                inputContext: inputContext.trimmedOrNil,
                captureSource: .composer
            )
            _ = try memoryRepository.createMemory(from: draft)
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

