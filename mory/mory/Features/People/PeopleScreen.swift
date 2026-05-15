import SwiftUI

struct PeopleScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var people: [PersonMemorySummary] = []
    @State private var themes: [ThemeMemorySummary] = []
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

                            if !person.themeLabels.isEmpty {
                                Text(person.themeLabels.joined(separator: " · "))
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
            people = try memoryRepository.fetchPeopleSummaries(limit: 20)
            themes = try memoryRepository.fetchThemeSummaries(limit: 20)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
