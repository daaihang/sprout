import SwiftUI

struct MemoryDetailView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let recordID: UUID

    @State private var snapshot: MemoryDetailSnapshot?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let snapshot {
                Section("Record") {
                    LabeledContent("Source", value: snapshot.record.captureSource.rawValue)
                    if let mood = snapshot.record.userMood {
                        LabeledContent("Mood", value: mood)
                    }
                    if let inputContext = snapshot.record.inputContext {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Input Context")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(inputContext)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 2)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Raw Capture")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(snapshot.record.rawText)
                            .font(.body)
                    }
                    Text(snapshot.record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Artifacts") {
                    if snapshot.artifacts.isEmpty {
                        Text("No artifacts linked yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.artifacts) { artifact in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(artifact.title)
                                        .font(.headline)
                                    Spacer(minLength: 12)
                                    Text(artifact.kind.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let summary = artifact.summary.trimmedOrNil {
                                    Text(summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                if let body = artifact.textContent.trimmedOrNil {
                                    Text(body)
                                        .font(.body)
                                        .lineLimit(6)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Next Layers") {
                    Text("Analysis snapshot, entity graph accumulation, and reflection outputs will attach here on top of the same record and artifact IDs.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            } else {
                Section {
                    ProgressView()
                }
            }
        }
        .navigationTitle("Memory")
        .task(id: recordID) {
            await load()
        }
    }

    private func load() async {
        do {
            snapshot = try memoryRepository.fetchMemoryDetail(recordID: recordID)
            errorMessage = snapshot == nil ? "Memory not found." : nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
