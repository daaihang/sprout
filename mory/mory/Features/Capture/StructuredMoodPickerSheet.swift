import SwiftUI

struct StructuredMoodPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialDraft: AffectSnapshotDraft?
    let onSave: (AffectSnapshotDraft) -> Void

    @State private var valence: Double
    @State private var arousal: Double
    @State private var dominance: Double
    @State private var intensity: Double
    @State private var selectedLabels: Set<AffectLabel>
    @State private var selectedToneHints: Set<ToneHint>
    @State private var rawInput: String

    init(initialDraft: AffectSnapshotDraft?, onSave: @escaping (AffectSnapshotDraft) -> Void) {
        self.initialDraft = initialDraft
        self.onSave = onSave
        _valence = State(initialValue: initialDraft?.valence ?? 0)
        _arousal = State(initialValue: initialDraft?.arousal ?? 0.45)
        _dominance = State(initialValue: initialDraft?.dominance ?? 0.5)
        _intensity = State(initialValue: initialDraft?.intensity ?? 0.55)
        _selectedLabels = State(initialValue: Set(initialDraft?.labels ?? []))
        _selectedToneHints = State(initialValue: Set(initialDraft?.toneHints ?? []))
        _rawInput = State(initialValue: initialDraft?.rawInput ?? "")
    }

    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: 8),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Mood Vector") {
                    LabeledContent("Valence", value: String(format: "%.2f", valence))
                    Slider(value: $valence, in: -1...1, step: 0.05)
                    LabeledContent("Arousal", value: String(format: "%.2f", arousal))
                    Slider(value: $arousal, in: 0...1, step: 0.05)
                    LabeledContent("Dominance", value: String(format: "%.2f", dominance))
                    Slider(value: $dominance, in: 0...1, step: 0.05)
                    LabeledContent("Intensity", value: String(format: "%.2f", intensity))
                    Slider(value: $intensity, in: 0...1, step: 0.05)
                }

                Section("Labels") {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                        ForEach(AffectLabel.allCases) { label in
                            SelectableChip(
                                title: label.rawValue,
                                isSelected: selectedLabels.contains(label)
                            ) {
                                toggleLabel(label)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Tone Hints") {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                        ForEach(ToneHint.allCases) { hint in
                            SelectableChip(
                                title: hint.rawValue,
                                isSelected: selectedToneHints.contains(hint)
                            ) {
                                toggleToneHint(hint)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Raw note") {
                    TextField("Optional note", text: $rawInput, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Structured Mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(makeDraft())
                        dismiss()
                    }
                }
            }
        }
    }

    private func toggleLabel(_ label: AffectLabel) {
        if selectedLabels.contains(label) {
            selectedLabels.remove(label)
        } else {
            selectedLabels.insert(label)
        }
    }

    private func toggleToneHint(_ hint: ToneHint) {
        if selectedToneHints.contains(hint) {
            selectedToneHints.remove(hint)
        } else {
            selectedToneHints.insert(hint)
        }
    }

    private func makeDraft() -> AffectSnapshotDraft {
        AffectSnapshotDraft(
            valence: valence,
            arousal: arousal,
            dominance: dominance,
            intensity: intensity,
            labels: Array(selectedLabels),
            toneHints: Array(selectedToneHints),
            sources: [.userSelected],
            confidence: 1,
            evidenceSummary: rawInput.trimmedOrNil,
            userConfirmed: true,
            rawInput: rawInput.trimmedOrNil
        )
    }
}

private struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(isSelected ? .accentColor : .secondary)
    }
}
