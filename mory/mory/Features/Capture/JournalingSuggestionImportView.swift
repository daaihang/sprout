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
    @State private var stateOfMindArousal = 0.4
    @State private var stateOfMindDominance = 0.6

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
                    LabeledContent("Arousal", value: String(format: "%.2f", stateOfMindArousal))
                    Slider(value: $stateOfMindArousal, in: 0...1, step: 0.05)
                    LabeledContent("Dominance", value: String(format: "%.2f", stateOfMindDominance))
                    Slider(value: $stateOfMindDominance, in: 0...1, step: 0.05)
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
        let suggestion = JournalingSuggestionDraft(
            title: title.trimmedOrNil,
            body: bodyText.trimmedOrNil,
            reflectionPrompt: reflectionPrompt.trimmedOrNil,
            locationTitle: locationTitle.trimmedOrNil,
            songTitle: songTitle.trimmedOrNil,
            artistName: artistName.trimmedOrNil,
            stateOfMindLabel: stateOfMindLabel.trimmedOrNil,
            stateOfMindValence: stateOfMindLabel.trimmedOrNil == nil ? nil : stateOfMindValence,
            stateOfMindArousal: stateOfMindLabel.trimmedOrNil == nil ? nil : stateOfMindArousal,
            stateOfMindDominance: stateOfMindLabel.trimmedOrNil == nil ? nil : stateOfMindDominance
        )
        onImport(service.makeCaptureDraft(from: suggestion))
        dismiss()
    }
}
