import SwiftUI

struct PersonProfileEditView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.dismiss) private var dismiss

    let entityID: UUID
    var onUpdated: (() -> Void)? = nil

    @State private var profile: PersonProfile?
    @State private var displayName = ""
    @State private var aliasesText = ""
    @State private var roleLabelsText = ""
    @State private var userNotes = ""
    @State private var relationshipToUser: EntityRelationshipToUser?
    @State private var automationPolicy: PersonProfileAutomationPolicy = .automatic
    @State private var sensitivity: ProfileSensitivity = .normal
    @State private var message: String?
    @State private var isSaving = false

    var body: some View {
        Form {
            if let profile {
                Section("Summary") {
                    LabeledContent("Entity ID", value: profile.entityID.uuidString)
                    LabeledContent("Mentions", value: "\(profile.sourceRecordIDs.count)")
                    LabeledContent("Field evidence", value: "\(profile.fieldEvidence.count)")
                    LabeledContent("Updated", value: profile.updatedAt.formatted(date: .abbreviated, time: .shortened))
                }

                Section("Editable Fields") {
                    TextField("Display name", text: $displayName)
                    TextField("Aliases (comma separated)", text: $aliasesText, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Role labels (comma separated)", text: $roleLabelsText, axis: .vertical)
                        .lineLimit(2...4)
                    Picker("Relationship", selection: $relationshipToUser) {
                        Text("none").tag(EntityRelationshipToUser?.none)
                        ForEach(EntityRelationshipToUser.allCases) { relationship in
                            Text(relationship.rawValue).tag(EntityRelationshipToUser?.some(relationship))
                        }
                    }
                    Picker("Automation", selection: $automationPolicy) {
                        ForEach(PersonProfileAutomationPolicy.allCases) { policy in
                            Text(policy.rawValue).tag(policy)
                        }
                    }
                    Picker("Sensitivity", selection: $sensitivity) {
                        ForEach(ProfileSensitivity.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    TextField("User notes", text: $userNotes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            } else {
                ContentUnavailableView("Person profile not found", systemImage: "person.crop.circle.badge.exclamationmark")
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
        .navigationTitle("Edit Person Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            load()
        }
    }

    @MainActor
    private func load() {
        do {
            let loaded = try memoryRepository.fetchPersonProfile(entityID: entityID)
            profile = loaded
            guard let loaded else {
                message = "Profile not found."
                return
            }
            displayName = loaded.displayName
            aliasesText = loaded.aliases.joined(separator: ", ")
            roleLabelsText = loaded.roleLabels.joined(separator: ", ")
            userNotes = loaded.userNotes ?? ""
            relationshipToUser = loaded.relationshipToUser
            automationPolicy = loaded.automationPolicy
            sensitivity = loaded.sensitivity
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func save() async {
        guard let profile else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let aliases = aliasesText
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let roleLabels = roleLabelsText
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if displayName.trimmedOrNil != profile.displayName {
                _ = try memoryRepository.applyPersonProfileMutation(
                    PersonProfileMutation(
                        entityID: entityID,
                        field: .displayName,
                        stringValue: displayName.trimmedOrNil,
                        note: "Updated display name in product editor."
                    )
                )
            }
            if aliases != profile.aliases {
                _ = try memoryRepository.applyPersonProfileMutation(
                    PersonProfileMutation(
                        entityID: entityID,
                        field: .aliases,
                        stringListValue: aliases,
                        note: "Updated aliases in product editor."
                    )
                )
            }
            if roleLabels != profile.roleLabels {
                _ = try memoryRepository.applyPersonProfileMutation(
                    PersonProfileMutation(
                        entityID: entityID,
                        field: .roleLabels,
                        stringListValue: roleLabels,
                        note: "Updated role labels in product editor."
                    )
                )
            }
            if relationshipToUser != profile.relationshipToUser {
                _ = try memoryRepository.applyPersonProfileMutation(
                    PersonProfileMutation(
                        entityID: entityID,
                        field: .relationshipToUser,
                        relationshipValue: relationshipToUser,
                        note: "Updated relationship in product editor."
                    )
                )
            }
            if userNotes.trimmedOrNil != profile.userNotes?.trimmedOrNil {
                _ = try memoryRepository.applyPersonProfileMutation(
                    PersonProfileMutation(
                        entityID: entityID,
                        field: .userNotes,
                        stringValue: userNotes.trimmedOrNil,
                        note: "Updated notes in product editor."
                    )
                )
            }
            if automationPolicy != profile.automationPolicy {
                _ = try memoryRepository.applyPersonProfileMutation(
                    PersonProfileMutation(
                        entityID: entityID,
                        field: .automationPolicy,
                        automationPolicyValue: automationPolicy,
                        note: "Updated automation policy in product editor."
                    )
                )
            }
            if sensitivity != profile.sensitivity {
                _ = try memoryRepository.applyPersonProfileMutation(
                    PersonProfileMutation(
                        entityID: entityID,
                        field: .sensitivity,
                        sensitivityValue: sensitivity,
                        note: "Updated sensitivity in product editor."
                    )
                )
            }
            message = "Saved."
            load()
            onUpdated?()
        } catch {
            message = error.localizedDescription
        }
    }
}
