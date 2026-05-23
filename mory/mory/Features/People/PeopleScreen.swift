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

            Section("people.section.people") {
                if people.isEmpty {
                    Text("people.empty.people")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(people, id: \.id) { person in
                        NavigationLink {
                            PersonDetailView(entityID: person.entity.id)
                                .moryHidesTabChrome()
                        } label: {
                            PersonRow(person: person)
                        }
                    }
                }
            }

            Section("people.section.themes") {
                if themes.isEmpty {
                    Text("people.empty.themes")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(themes, id: \.id) { theme in
                        NavigationLink {
                            EntityDetailView(entityID: theme.entity.id)
                                .moryHidesTabChrome()
                        } label: {
                            ThemeRow(theme: theme)
                        }
                    }
                }
            }

            Section("people.section.places") {
                if places.isEmpty {
                    Text("people.empty.places")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(places, id: \.id) { place in
                        NavigationLink {
                            EntityDetailView(entityID: place.entity.id)
                                .moryHidesTabChrome()
                        } label: {
                            ThemeRow(theme: place)
                        }
                    }
                }
            }

            Section("people.section.decisions") {
                if decisions.isEmpty {
                    Text("people.empty.decisions")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(decisions, id: \.id) { decision in
                        NavigationLink {
                            EntityDetailView(entityID: decision.entity.id)
                                .moryHidesTabChrome()
                        } label: {
                            ThemeRow(theme: decision)
                        }
                    }
                }
            }
        }
        .navigationTitle("people.nav.title")
        .moryHidesTabChrome()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PersonMergeSplitView()
                        .moryHidesTabChrome()
                } label: {
                    Label("Manage People", systemImage: "person.2.badge.gearshape")
                }
            }
        }
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
                Text("common.attachmentCount \(person.artifactCount)")
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
                Text("common.attachmentCount \(theme.artifactCount)")
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
                Text("people.theme.stats \(theme.relatedArcs.count) \(theme.relatedReflections.count)")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
