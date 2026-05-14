import SwiftUI
import SwiftData

struct ReflectionEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let recordID: UUID?
    let arcID: UUID?

    @State private var title: String = ""
    @State private var body: String = ""
    @State private var status: ReflectionStatus = .active

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !body.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reflection Title") {
                    TextField("What's this reflection about?", text: $title)
                }

                Section("Reflection Notes") {
                    TextEditor(text: $body)
                        .frame(minHeight: 120)
                }

                if let recordID {
                    Section("Context") {
                        Text("Linked to record")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let arcID {
                    Section("Context") {
                        Text("Linked to phase")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        Text("Active").tag(ReflectionStatus.active)
                        Text("Archived").tag(ReflectionStatus.archived)
                        Text("Dismissed").tag(ReflectionStatus.dismissed)
                    }
                }
            }
            .navigationTitle("Create Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveReflection()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func saveReflection() {
        let reflection = ReflectionSnapshot(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            body: body.trimmingCharacters(in: .whitespaces),
            sourceRecordIDs: recordID.map { [$0] } ?? [],
            sourceEntityIDs: [],
            linkedTemporalArcID: arcID,
            sourceAnalysisIDs: [],
            sourceArtifactIDs: [],
            status: status,
            createdAt: Date(),
            updatedAt: Date(),
            determinedLocally: true,
            evidenceSummary: nil,
            confidencePercentage: nil,
            aiGenerationPrompt: nil,
            tagClusters: [],
            relationshipSuggestions: []
        )

        modelContext.insert(reflection)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    ReflectionEditView(recordID: UUID(), arcID: nil)
}
