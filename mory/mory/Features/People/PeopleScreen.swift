import SwiftUI

struct PeopleScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var people: [EntityDetailSnapshot] = []
    @State private var themes: [EntityDetailSnapshot] = []
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("People") {
                if people.isEmpty {
                    Text("People entities will appear here once the graph layer starts accumulating person nodes and links.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(people, id: \.id) { person in
                        NavigationLink {
                            PersonDetailView(entityID: person.entity.id)
                        } label: {
                            PersonRow(person: person)
                        }
                    }
                }
            }

            Section("Themes") {
                if themes.isEmpty {
                    Text("Theme entities will appear here once the graph layer accumulates reusable theme nodes.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(themes, id: \.id) { theme in
                        NavigationLink {
                            EntityDetailView(entityID: theme.entity.id)
                        } label: {
                            ThemeRow(theme: theme)
                        }
                    }
                }
            }
        }
        .navigationTitle("People")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        do {
            people = try memoryRepository.fetchEntityDetails(kind: .person, limit: 20)
            themes = try memoryRepository.fetchEntityDetails(kind: .theme, limit: 20)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PersonRow: View {
    let person: EntityDetailSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(person.entity.displayName)
                    .font(.headline)
                Spacer()
                Text("\(person.artifactCount) artifacts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let summary = person.entity.summary.trimmedOrNil {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !person.relatedThemes.isEmpty {
                Text(person.relatedThemes.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !person.relatedMemories.isEmpty {
                Text(person.relatedMemories.map(\.title).joined(separator: " | "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ThemeRow: View {
    let theme: EntityDetailSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(theme.entity.displayName)
                    .font(.headline)
                Spacer()
                Text("\(theme.artifactCount) artifacts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !theme.relatedPeople.isEmpty {
                Text(theme.relatedPeople.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !theme.relatedMemories.isEmpty {
                Text(theme.relatedMemories.map(\.title).joined(separator: " | "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !theme.relatedArcs.isEmpty {
                Text("\(theme.relatedArcs.count) arcs · \(theme.relatedReflections.count) reflections")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
