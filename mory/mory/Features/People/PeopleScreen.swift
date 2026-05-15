import SwiftUI

struct PeopleScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var people: [PersonMemorySummary] = []
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
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
