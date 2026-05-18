import SwiftUI

struct MemoryBoardCard: View {
    let memory: MemorySummary
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(memory.title).font(.headline).lineLimit(2)
            Text(memory.summaryText).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            if let contextSummary {
                Text(contextSummary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            HStack {
                Text(reason)
                Spacer()
                Text(memory.record.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var contextSummary: String? {
        memory.contextArtifacts
            .map(\.summary)
            .compactMap(\.trimmedOrNil)
            .prefix(3)
            .joined(separator: " | ")
            .trimmedOrNil
    }
}

struct ArcBoardCard: View {
    let arc: TemporalArc
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(arc.title).font(.headline).lineLimit(2)
            Text(arc.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            HStack {
                Text("home.board.arc.ongoing \(arc.sourceRecordIDs.count)")
                Spacer()
                Text(reason)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

struct ReflectionBoardCard: View {
    let reflection: ReflectionSnapshot
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reflection.title).font(.headline).lineLimit(2)
            Text(reflection.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            HStack {
                Text(reflection.statusLabel)
                Spacer()
                Text(reason)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
