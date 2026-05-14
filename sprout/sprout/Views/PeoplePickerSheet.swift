import SwiftUI

struct PeoplePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLocalization.self) private var localization
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    @Binding var selectedPeople: [PersonCardItem]

    @State private var searchText = ""
    @State private var newPersonName = ""
    @State private var newPersonNickname = ""
    @State private var newPersonRelationship = ""

    private var allPeople: [PersonCardItem] {
        memoryRepository
            .peopleIndex()
            .map { entry in
                PersonCardItem(
                    id: entry.entity.id,
                    name: entry.entity.canonicalName,
                    nickname: entry.entity.displayName == entry.entity.canonicalName ? nil : entry.entity.displayName,
                    relationship: entry.themeNames.first,
                    lastMentionedAt: entry.lastSeenAt,
                    mentionCount: entry.relatedRecordCount
                )
            }
    }

    private var filteredPeople: [PersonCardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return allPeople }
        return allPeople.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.nickname.localizedCaseInsensitiveContains(query)
                || $0.relationship.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(t("content.people_picker.section.selected", "Selected")) {
                    if selectedPeople.isEmpty {
                        Text(t("content.people_picker.empty.selected", "No people selected yet"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(selectedPeople, id: \.id) { person in
                            personRow(person, selected: true)
                        }
                    }
                }

                Section(t("content.people_picker.section.quick_create", "Quick Create")) {
                    TextField(t("content.people_picker.field.name", "Name"), text: $newPersonName)
                    TextField(t("content.people_picker.field.nickname_optional", "Nickname (Optional)"), text: $newPersonNickname)
                    TextField(t("content.people_picker.field.relationship_optional", "Relationship (Optional)"), text: $newPersonRelationship)

                    Button {
                        createAndSelectPerson()
                    } label: {
                        Label(t("content.people_picker.action.create_select", "Create and Select"), systemImage: "plus")
                    }
                    .disabled(newPersonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section(t("content.people_picker.section.list", "People")) {
                    if filteredPeople.isEmpty {
                        Text(t("content.people_picker.empty.search", "No people found"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredPeople, id: \.id) { person in
                            personRow(person, selected: isSelected(person))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleSelection(for: person)
                                }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: t("content.people_picker.search", "Search people"))
            .navigationTitle(t("content.people_picker.title", "Select People"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t("common.cancel", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("common.done", "Done")) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func personRow(_ person: PersonCardItem, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.14))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(person.initials)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName)
                    .font(.subheadline.weight(.medium))
                if !person.subtitle.isEmpty {
                    Text(person.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private func isSelected(_ person: PersonCardItem) -> Bool {
        selectedPeople.contains(where: { $0.id == person.id })
    }

    private func toggleSelection(for person: PersonCardItem) {
        if let index = selectedPeople.firstIndex(where: { $0.id == person.id }) {
            selectedPeople.remove(at: index)
        } else {
            selectedPeople.append(person)
        }
    }

    private func createAndSelectPerson() {
        selectedPeople.append(
            PersonCardItem(
                name: newPersonName.trimmingCharacters(in: .whitespacesAndNewlines),
                nickname: trimmedOrNil(newPersonNickname) ?? "",
                relationship: trimmedOrNil(newPersonRelationship) ?? ""
            )
        )
        newPersonName = ""
        newPersonNickname = ""
        newPersonRelationship = ""
    }

    private func trimmedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}
