import SwiftUI

struct JournalingSuggestionImportView: View {
    @Environment(\.dismiss) private var dismiss

    let onImport: (MemoryCaptureDraft) -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var reflectionPrompt = ""
    @State private var locationTitle = ""
    @State private var songTitle = ""
    @State private var artistName = ""
    @State private var stateOfMindLabel = ""
    @State private var stateOfMindValence = 0.0
    @State private var stateOfMindClassification = ""
    @State private var stateOfMindKind = "daily mood"
    @State private var message: String?

    private let service = JournalingSuggestionContextService()

    private var availability: JournalingSuggestionAvailability {
        service.availability()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Journaling Suggestions Status") {
                    LabeledContent("Available", value: availability.isAvailable ? "Yes" : "No")
                    LabeledContent("Reason", value: availability.reason.rawValue)
                    Text(availability.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Apple Picker") {
                    AppleJournalingSuggestionPickerControl { suggestion in
                        importSuggestion(suggestion)
                    } onError: { text in
                        message = text
                    }
                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Fallback Draft") {
                    TextField("Title", text: $title)
                    TextField("Body", text: $bodyText, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Reflection prompt", text: $reflectionPrompt)
                    TextField("Place", text: $locationTitle)
                    TextField("Song", text: $songTitle)
                    TextField("Artist", text: $artistName)
                }

                Section("State Of Mind") {
                    TextField("Label (e.g. calm, relieved)", text: $stateOfMindLabel)
                    LabeledContent("Valence", value: String(format: "%.2f", stateOfMindValence))
                    Slider(value: $stateOfMindValence, in: -1...1, step: 0.05)
                    TextField("Classification (e.g. pleasant)", text: $stateOfMindClassification)
                    TextField("Kind (daily mood / momentary emotion)", text: $stateOfMindKind)
                }
            }
            .navigationTitle("Journaling Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importDraft()
                    }
                }
            }
        }
    }

    private func importDraft() {
        var bundle = JournalingEvidenceBundle()
        if let prompt = reflectionPrompt.trimmedOrNil {
            bundle.reflections.append(JournalingReflectionEvidence(prompt: prompt))
        }
        if let place = locationTitle.trimmedOrNil {
            bundle.locations.append(JournalingLocationEvidence(title: place, place: place))
        }
        if let song = songTitle.trimmedOrNil {
            bundle.media.append(JournalingMediaEvidence(
                kind: .song,
                title: song,
                artist: artistName.trimmedOrNil,
                metadata: ["artist": artistName.trimmedOrNil ?? ""].filter { !$0.value.isEmpty }
            ))
        }
        if let label = stateOfMindLabel.trimmedOrNil {
            bundle.stateOfMind.append(ExternalCaptureAffectEvidence(
                source: .journalSuggestionStateOfMind,
                label: label,
                labels: [label],
                valence: stateOfMindValence,
                valenceClassification: stateOfMindClassification.trimmedOrNil,
                kind: stateOfMindKind.trimmedOrNil,
                rawInput: label,
                confidence: 0.9,
                userConfirmed: true,
                metadata: [
                    "valence": String(stateOfMindValence),
                    "valenceClassification": stateOfMindClassification.trimmedOrNil ?? "",
                    "kind": stateOfMindKind.trimmedOrNil ?? ""
                ].filter { !$0.value.isEmpty }
            ))
        }
        let suggestion = JournalingSuggestionDraft(
            title: title.trimmedOrNil,
            body: bodyText.trimmedOrNil,
            bundle: bundle
        )
        importSuggestion(suggestion)
    }

    private func importSuggestion(_ suggestion: JournalingSuggestionDraft) {
        onImport(service.makeCaptureDraft(from: suggestion))
        dismiss()
    }
}
