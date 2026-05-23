import SwiftUI

struct PersonDetailView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let entityID: UUID

    @State private var snapshot: PersonDetailSnapshot?
    @State private var profile: PersonProfile?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let snapshot {
                Section("person.section.info") {
                    Text(snapshot.summary.entity.displayName)
                        .font(.headline)
                    if let summary = snapshot.summary.entity.summary.trimmedOrNil {
                        Text(summary)
                            .foregroundStyle(.secondary)
                    }
                    Text("person.stats \(snapshot.summary.artifactCount) \(snapshot.summary.reflectionCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Person Profile") {
                    if let profile {
                        LabeledContent("Relationship", value: profile.relationshipToUser?.rawValue ?? "none")
                        LabeledContent("Automation", value: profile.automationPolicy.rawValue)
                        LabeledContent("Sensitivity", value: profile.sensitivity.rawValue)
                        LabeledContent("Importance", value: profile.importanceScore.map { String(format: "%.2f", $0) } ?? "none")
                        LabeledContent("Interaction", value: profile.interactionFrequency.rawValue)
                        if !profile.commonContextLabels.isEmpty {
                            Text("Contexts: \(profile.commonContextLabels.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let notes = profile.userNotes?.trimmedOrNil {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let portrait = profile.aiPortrait?.summary.trimmedOrNil {
                            Text(portrait)
                                .font(.caption)
                        }
                        Text("Evidence: \(profile.fieldEvidence.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No person profile yet.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Profile Actions") {
                    NavigationLink {
                        PersonProfileEditView(entityID: entityID) {
                            Task { await load() }
                        }
                    } label: {
                        Label("Edit Person Profile", systemImage: "slider.horizontal.3")
                    }
                    NavigationLink {
                        PersonMergeSplitView()
                    } label: {
                        Label("Manage People Merge/Split", systemImage: "person.2.badge.gearshape")
                    }
                }

                Section("common.section.relatedMemories") {
                    if snapshot.summary.relatedMemories.isEmpty {
                        Text("common.empty.relatedMemories")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.summary.relatedMemories) { memory in
                            NavigationLink {
                                MemoryDetailView(recordID: memory.record.id)
                                    .moryHidesTabChrome()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(memory.title)
                                        .font(.headline)
                                    Text(memory.summaryText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }

                Section("common.section.themes") {
                    if snapshot.summary.themeLabels.isEmpty {
                        Text("common.empty.themes")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(snapshot.summary.themeLabels.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("common.section.arcs") {
                    if snapshot.relatedArcs.isEmpty {
                        Text("common.empty.arcs")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.relatedArcs) { arc in
                            NavigationLink {
                                ArcDetailView(arcID: arc.arc.id)
                                    .moryHidesTabChrome()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(arc.arc.title)
                                        .font(.headline)
                                    Text(arc.arc.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }

                Section("common.section.reflections") {
                    if snapshot.relatedReflections.isEmpty {
                        Text("common.empty.reflections")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.relatedReflections) { reflection in
                            NavigationLink {
                                ReflectionDetailView(reflectionID: reflection.reflection.id)
                                    .moryHidesTabChrome()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(reflection.reflection.title)
                                        .font(.headline)
                                    Text(reflection.reflection.body)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("person.nav.title")
        .moryHidesTabChrome()
        .task {
            await load()
        }
    }

    private func load() async {
        do {
            snapshot = try memoryRepository.fetchPersonDetail(entityID: entityID)
            profile = try memoryRepository.fetchPersonProfile(entityID: entityID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
