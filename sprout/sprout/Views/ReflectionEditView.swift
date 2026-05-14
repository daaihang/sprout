import SwiftUI

struct ReflectionEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLocalization.self) private var localization
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let reflectionID: UUID?
    let recordID: UUID?
    let arcID: UUID?

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var status: ReflectionStatus = .active

    private var existingReflection: ReflectionSnapshot? {
        if let reflectionID {
            return memoryRepository.reflection(reflectionID)
        }
        if let arcID {
            return memoryRepository.linkedReflection(forArcID: arcID)
        }
        if let recordID {
            return memoryRepository.recordReflection(forRecordID: recordID)
        }
        return nil
    }

    private var isEditingExistingReflection: Bool {
        existingReflection != nil
    }

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
            .navigationTitle(isEditingExistingReflection ? "Edit Reflection" : "Create Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditingExistingReflection ? "Update" : "Save") {
                        saveReflection()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .onAppear(perform: loadExistingReflectionIfNeeded)
    }

    private func saveReflection() {
        let reflectionType: ReflectionType = arcID == nil ? .record : .phase
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceRecordIDs = existingReflection?.sourceRecordIDs ?? defaultSourceRecordIDs
        let sourceArtifactIDs = existingReflection?.sourceArtifactIDs ?? defaultSourceArtifactIDs
        let sourceEntityIDs = existingReflection?.sourceEntityIDs ?? defaultSourceEntityIDs

        let reflection = ReflectionSnapshot(
            id: existingReflection?.id ?? UUID(),
            type: reflectionType,
            title: trimmedTitle,
            body: trimmedNotes,
            evidenceSummary: existingReflection?.evidenceSummary,
            confidence: existingReflection?.confidence,
            status: status,
            linkedTemporalArcID: arcID,
            sourceRecordIDs: sourceRecordIDs,
            sourceArtifactIDs: sourceArtifactIDs,
            sourceEntityIDs: sourceEntityIDs,
            createdAt: existingReflection?.createdAt ?? Date(),
            savedAt: status == .saved ? Date() : nil,
            dismissedAt: status == .dismissed ? Date() : nil
        )

        memoryRepository.upsertReflection(reflection)
        dismiss()
    }

    private func loadExistingReflectionIfNeeded() {
        guard let existingReflection else { return }
        if title.isEmpty {
            title = existingReflection.title
        }
        if notes.isEmpty {
            notes = existingReflection.body
        }
        status = existingReflection.status
    }

    private var defaultSourceRecordIDs: [UUID] {
        if let recordID {
            return [recordID]
        }
        if let arcID, let arc = memoryRepository.temporalArc(for: arcID) {
            return arc.sourceRecordIDs
        }
        return []
    }

    private var defaultSourceArtifactIDs: [UUID] {
        if let recordID, let memoryView = memoryRepository.memoryView(for: recordID) {
            return memoryView.artifacts.map(\.id)
        }
        if let arcID, let arc = memoryRepository.temporalArc(for: arcID) {
            return arc.sourceArtifactIDs
        }
        return []
    }

    private var defaultSourceEntityIDs: [UUID] {
        if let recordID, let memoryView = memoryRepository.memoryView(for: recordID) {
            return memoryView.linkedEntities.map(\.id)
        }
        if let arcID, let evidenceView = memoryRepository.arcEvidenceView(for: arcID) {
            return evidenceView.linkedEntities.map(\.id)
        }
        return []
    }
}

#Preview {
    ReflectionEditView(reflectionID: nil, recordID: UUID(), arcID: nil)
}
