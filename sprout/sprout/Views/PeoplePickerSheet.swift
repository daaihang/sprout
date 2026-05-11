import SwiftUI
import SwiftData

struct PeoplePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.mentionCount, order: .reverse) private var people: [Person]

    @Binding var selectedPeople: [Person]

    @State private var searchText = ""
    @State private var newPersonName = ""
    @State private var newPersonNickname = ""
    @State private var newPersonRelationship = ""

    private var filteredPeople: [Person] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return people }
        return people.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.nickname ?? "").localizedCaseInsensitiveContains(query)
                || ($0.relationship ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("已选择") {
                    if selectedPeople.isEmpty {
                        Text("还没有选择人物")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(selectedPeople, id: \.id) { person in
                            personRow(person, selected: true)
                        }
                    }
                }

                Section("快速新建") {
                    TextField("姓名", text: $newPersonName)
                    TextField("昵称（可选）", text: $newPersonNickname)
                    TextField("关系（可选）", text: $newPersonRelationship)

                    Button {
                        createAndSelectPerson()
                    } label: {
                        Label("新建并选择", systemImage: "plus")
                    }
                    .disabled(newPersonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("人物列表") {
                    if filteredPeople.isEmpty {
                        Text("没有找到人物")
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
            .searchable(text: $searchText, prompt: "搜索人物")
            .navigationTitle("选择人物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func personRow(_ person: Person, selected: Bool) -> some View {
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
                if !person.secondaryLabel.isEmpty {
                    Text(person.secondaryLabel)
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

    private func isSelected(_ person: Person) -> Bool {
        selectedPeople.contains(where: { $0.id == person.id })
    }

    private func toggleSelection(for person: Person) {
        if let index = selectedPeople.firstIndex(where: { $0.id == person.id }) {
            selectedPeople.remove(at: index)
        } else {
            selectedPeople.append(person)
        }
    }

    private func createAndSelectPerson() {
        let person = Person()
        person.name = newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)
        person.nickname = trimmedOrNil(newPersonNickname)
        person.relationship = trimmedOrNil(newPersonRelationship)
        modelContext.insert(person)
        selectedPeople.append(person)
        newPersonName = ""
        newPersonNickname = ""
        newPersonRelationship = ""
    }

    private func trimmedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
