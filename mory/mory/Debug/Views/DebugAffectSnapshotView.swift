import SwiftUI

struct DebugAffectSnapshotView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @State private var snapshots: [AffectSnapshot] = []
    @State private var correctionEvents: [CorrectionEvent] = []
    @State private var availability = JournalingSuggestionContextService().availability()
    @State private var message: String?

    var body: some View {
        List {
            Section("Journaling Suggestions") {
                DebugAffectValue(title: "Available", value: availability.isAvailable ? "yes" : "no")
                DebugAffectValue(title: "Reason", value: availability.reason.rawValue)
                DebugAffectValue(title: "Detail", value: availability.detail)
            }

            Section("Actions") {
                Button("Reload affect snapshots") {
                    Task { await load() }
                }
                DebugActionNotice(
                    .mutating,
                    message: "Seeding creates a real debug memory with StateOfMind evidence."
                )
                Button("Seed journaling StateOfMind draft") {
                    Task { await seedJournalingSuggestionDraft() }
                }
            }

            if let message {
                Section("Status") {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Affect Corrections") {
                if correctionEvents.isEmpty {
                    Text("No affect correction events.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(correctionEvents, id: \.id) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.note ?? event.kind.rawValue)
                                .font(.subheadline.weight(.semibold))
                            Text(event.metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "\n"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Snapshots") {
                if snapshots.isEmpty {
                    Text("No affect snapshots yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshots) { snapshot in
                        DebugAffectSnapshotRow(snapshot: snapshot)
                    }
                }
            }
        }
        .navigationTitle("Affect Snapshots")
        .task {
            await load()
        }
    }

    @MainActor
    private func load() async {
        do {
            snapshots = try memoryRepository.fetchAffectSnapshots(recordID: nil, limit: 50)
            correctionEvents = try memoryRepository.fetchCorrectionEvents(kind: .affectCorrection, limit: 20)
            availability = JournalingSuggestionContextService().availability()
            message = "Loaded \(snapshots.count) snapshot(s)."
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func seedJournalingSuggestionDraft() async {
        do {
            let service = JournalingSuggestionContextService()
            let draft = service.makeCaptureDraft(
                from: JournalingSuggestionDraft(
                    title: "System suggestion mood evidence",
                    body: "Imported system suggestion for Phase 4 debug.",
                    bundle: JournalingEvidenceBundle(
                        locations: [JournalingLocationEvidence(title: "Debug Location", place: "Debug Location")],
                        media: [JournalingMediaEvidence(kind: .song, title: "Debug Track", artist: "Mory")],
                        reflections: [JournalingReflectionEvidence(prompt: "What made this moment feel different?")],
                        stateOfMind: [
                            ExternalCaptureAffectEvidence(
                                source: .journalSuggestionStateOfMind,
                                label: "relieved",
                                labels: ["relieved"],
                                valence: 0.65,
                                valenceClassification: "pleasant",
                                kind: "daily mood",
                                rawInput: "relieved",
                                confidence: 0.9,
                                metadata: [
                                    "labels": "relieved",
                                    "valence": "0.65",
                                    "valenceClassification": "pleasant",
                                    "kind": "daily mood"
                                ]
                            )
                        ]
                    )
                )
            )
            _ = try await memoryRepository.createMemory(from: draft)
            await load()
            message = "Seeded journaling suggestion draft and persisted StateOfMind evidence."
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct DebugAffectSnapshotRow: View {
    let snapshot: AffectSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot.primaryMoodText)
                .font(.headline)
            DebugAffectValue(title: "Record", value: snapshot.recordID.uuidString)
            DebugAffectValue(title: "Vector", value: vectorText)
            DebugAffectValue(title: "Labels", value: snapshot.labels.map(\.rawValue).joined(separator: ", "))
            DebugAffectValue(title: "Tone", value: snapshot.toneHints.map(\.rawValue).joined(separator: ", "))
            DebugAffectValue(title: "Sources", value: snapshot.sources.map(\.rawValue).joined(separator: ", "))
            DebugAffectValue(title: "Confidence", value: snapshot.confidence.map { String(format: "%.2f", $0) } ?? "none")
            DebugAffectValue(title: "User confirmed", value: snapshot.userConfirmed ? "yes" : "no")
            if !snapshot.evidence.isEmpty {
                Text(snapshot.evidence.map { "\($0.source.rawValue): \($0.summary)" }.joined(separator: "\n"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var vectorText: String {
        [
            snapshot.valence.map { "v=\(String(format: "%.2f", $0))" },
            snapshot.arousal.map { "a=\(String(format: "%.2f", $0))" },
            snapshot.dominance.map { "d=\(String(format: "%.2f", $0))" },
            snapshot.intensity.map { "i=\(String(format: "%.2f", $0))" }
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
}

private struct DebugAffectValue: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "none" : value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }
}
