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
                    ForEach(people) { person in
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

                            if !person.relatedReflections.isEmpty {
                                Text("\(person.relatedReflections.count) reflections · \(person.relatedArcs.count) arcs")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Themes") {
                if themes.isEmpty {
                    Text("Theme entities will appear here once the graph layer accumulates reusable theme nodes.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(themes) { theme in
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
