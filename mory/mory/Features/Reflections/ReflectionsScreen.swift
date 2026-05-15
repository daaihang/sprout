import SwiftUI

struct ReflectionsScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var reflections: [ReflectionSummarySnapshot] = []
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("reflections.section.title") {
                if reflections.isEmpty {
                    Text("reflections.empty.description")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(reflections) { item in
                        NavigationLink {
                            ReflectionDetailView(reflectionID: item.reflection.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.reflection.title)
                                        .font(.headline)
                                    Spacer()
                                    Text(item.reflection.statusLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(item.reflection.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                Text(item.reflection.evidenceSummary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                if let linkedArc = item.linkedArc {
                                    Text(linkedArc.title)
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                                if !item.relatedMemories.isEmpty {
                                    Text(item.relatedMemories.map(\.title).joined(separator: " | "))
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
        }
        .navigationTitle("reflections.nav.title")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        do {
            reflections = try memoryRepository.fetchReflectionSummaries(limit: 20)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
