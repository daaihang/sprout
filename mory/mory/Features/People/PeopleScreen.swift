import SwiftUI

struct PeopleScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var people: [EntityDetailSnapshot] = []
    @State private var themes: [EntityDetailSnapshot] = []
    @State private var places: [EntityDetailSnapshot] = []
    @State private var decisions: [EntityDetailSnapshot] = []
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
                    Text("People will appear here after captures accumulate into stable graph entities.")
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
                    Text("Themes will appear here after repeated patterns become reusable graph nodes.")
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

            Section("Places") {
                if places.isEmpty {
                    Text("Places will appear here when captures carry reusable place references.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(places, id: \.id) { place in
                        NavigationLink {
                            EntityDetailView(entityID: place.entity.id)
                        } label: {
                            ThemeRow(theme: place)
                        }
                    }
                }
            }

            Section("Decisions") {
                if decisions.isEmpty {
                    Text("Decisions will appear here when the graph extracts stable decision objects.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(decisions, id: \.id) { decision in
                        NavigationLink {
                            EntityDetailView(entityID: decision.entity.id)
                        } label: {
                            ThemeRow(theme: decision)
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
            places = try memoryRepository.fetchEntityDetails(kind: .place, limit: 20)
            decisions = try memoryRepository.fetchEntityDetails(kind: .decision, limit: 20)
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
