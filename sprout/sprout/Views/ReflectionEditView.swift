import SwiftUI

struct ReflectionEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLocalization.self) private var localization
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let recordID: UUID?
    let arcID: UUID?

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var status: ReflectionStatus = .active

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !notes.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reflection Title") {
                    TextField("What's this reflection about?", text: $title)
                }

                Section("Reflection Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                }

                if recordID != nil {
                    Section("Context") {
                        Text(localization.string("common.linked_to_record", default: "Linked to record"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if arcID != nil {
                    Section("Context") {
                        Text(localization.string("common.linked_to_phase", default: "Linked to phase"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        Text(localization.string("common.active", default: "Active")).tag(ReflectionStatus.active)
                        Text(localization.string("common.saved", default: "Saved")).tag(ReflectionStatus.saved)
                        Text(localization.string("common.dismissed", default: "Dismissed")).tag(ReflectionStatus.dismissed)
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
        let reflectionType: ReflectionType = arcID == nil ? .record : .phase
        let reflection = ReflectionSnapshot(
            id: UUID(),
            type: reflectionType,
            title: title.trimmingCharacters(in: .whitespaces),
            body: notes.trimmingCharacters(in: .whitespaces),
            evidenceSummary: nil,
            confidence: nil,
            status: status,
            linkedTemporalArcID: arcID,
            sourceRecordIDs: recordID.map { [$0] } ?? [],
            sourceArtifactIDs: [],
            sourceEntityIDs: [],
            createdAt: Date(),
            savedAt: status == .saved ? Date() : nil,
            dismissedAt: status == .dismissed ? Date() : nil
        )

        memoryRepository.upsertReflection(reflection)
        dismiss()
    }
}

#Preview {
    ReflectionEditView(recordID: UUID(), arcID: nil)
}
