import SwiftUI
import SwiftData

struct DebugValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

struct DebugProgressRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct DebugErrorMessageRow: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption.monospaced())
                .foregroundStyle(.orange)
                .textSelection(.enabled)
        }
    }
}

struct DebugCapabilityChecklistRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct DebugEndpointProbe: Identifiable {
    let id = UUID()
    let name: String
    let statusCode: Int?
    let latency: TimeInterval
    let error: String?

    var isReachable: Bool {
        statusCode != nil
    }

    var latencyText: String {
        String(format: "%.0f ms", latency * 1000)
    }

    var detail: String {
        if let statusCode {
            return "HTTP \(statusCode)"
        }
        return error ?? String(localized: "debug.value.unknown")
    }
}

struct DebugQualityGateRow: Identifiable {
    let id = UUID()
    let title: String
    let passed: Bool
    let result: String
    let detail: String
}

struct DebugPermissionRow: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

struct DebugStorageCount: Identifiable {
    let id = UUID()
    let title: String
    let value: Int
}

struct DebugStorageIssue: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

struct DebugStorageIntegrityReport {
    let counts: [DebugStorageCount]
    let issues: [DebugStorageIssue]

    var issueCount: Int {
        issues.reduce(0) { total, issue in
            let firstNumber = issue.detail.split(separator: " ").first.flatMap { Int($0) }
            return total + (firstNumber ?? 1)
        }
    }

    @MainActor
    static func build(modelContext: ModelContext) throws -> DebugStorageIntegrityReport {
        let records = try modelContext.fetch(FetchDescriptor<RecordShellStore>())
        let artifacts = try modelContext.fetch(FetchDescriptor<ArtifactStore>())
        let analyses = try modelContext.fetch(FetchDescriptor<RecordAnalysisSnapshotStore>())
        let entities = try modelContext.fetch(FetchDescriptor<EntityNodeStore>())
        let edges = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>())
        let links = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        let arcs = try modelContext.fetch(FetchDescriptor<TemporalArcStore>())
        let reflections = try modelContext.fetch(FetchDescriptor<ReflectionSnapshotStore>())
        let pipelines = try modelContext.fetch(FetchDescriptor<MemoryPipelineStatusStore>())

        let recordIDs = Set(records.map(\.id))
        let artifactIDs = Set(artifacts.map(\.id))
        let entityIDs = Set(entities.map(\.id))
        let arcIDs = Set(arcs.map(\.id))

        var issues: [DebugStorageIssue] = []
        appendIssue(&issues, title: String(localized: "debug.storage.orphanArtifacts"), missingCount: artifacts.filter { !recordIDs.contains($0.recordID) }.count)
        appendIssue(&issues, title: String(localized: "debug.storage.missingRecordArtifacts"), missingCount: records.flatMap(\.artifactIDs).filter { !artifactIDs.contains($0) }.count)
        appendIssue(&issues, title: String(localized: "debug.storage.orphanAnalyses"), missingCount: analyses.filter { !recordIDs.contains($0.recordID) }.count)
        appendIssue(&issues, title: String(localized: "debug.storage.orphanPipelines"), missingCount: pipelines.filter { !recordIDs.contains($0.recordID) }.count)
        appendIssue(&issues, title: String(localized: "debug.storage.brokenLinks"), missingCount: links.filter { !artifactIDs.contains($0.artifactID) || !entityIDs.contains($0.entityID) }.count)
        appendIssue(&issues, title: String(localized: "debug.storage.brokenEdges"), missingCount: edges.filter { !entityIDs.contains($0.fromEntityID) || !entityIDs.contains($0.toEntityID) }.count)
        appendIssue(&issues, title: String(localized: "debug.storage.brokenArcs"), missingCount: arcs.filter {
            !$0.sourceRecordIDs.allSatisfy(recordIDs.contains)
                || !$0.sourceArtifactIDs.allSatisfy(artifactIDs.contains)
                || !$0.sourceEntityIDs.allSatisfy(entityIDs.contains)
        }.count)
        appendIssue(&issues, title: String(localized: "debug.storage.brokenReflections"), missingCount: reflections.filter {
            !$0.sourceRecordIDs.allSatisfy(recordIDs.contains)
                || !$0.sourceArtifactIDs.allSatisfy(artifactIDs.contains)
                || !$0.sourceEntityIDs.allSatisfy(entityIDs.contains)
                || ($0.linkedTemporalArcID.map { !arcIDs.contains($0) } ?? false)
        }.count)

        return DebugStorageIntegrityReport(
            counts: [
                DebugStorageCount(title: String(localized: "debug.storage.records"), value: records.count),
                DebugStorageCount(title: String(localized: "debug.storage.artifacts"), value: artifacts.count),
                DebugStorageCount(title: String(localized: "debug.storage.analyses"), value: analyses.count),
                DebugStorageCount(title: String(localized: "debug.storage.entities"), value: entities.count),
                DebugStorageCount(title: String(localized: "debug.storage.edges"), value: edges.count),
                DebugStorageCount(title: String(localized: "debug.storage.links"), value: links.count),
                DebugStorageCount(title: String(localized: "debug.storage.arcs"), value: arcs.count),
                DebugStorageCount(title: String(localized: "debug.storage.reflections"), value: reflections.count),
                DebugStorageCount(title: String(localized: "debug.storage.pipelines"), value: pipelines.count)
            ],
            issues: issues
        )
    }

    private static func appendIssue(_ issues: inout [DebugStorageIssue], title: String, missingCount: Int) {
        guard missingCount > 0 else { return }
        issues.append(DebugStorageIssue(title: title, detail: String(format: String(localized: "debug.storage.issueDetail"), missingCount)))
    }
}

// MARK: - Shared Debug Extensions

extension String {
    var nonEmptyDisplay: String {
        trimmedOrNil ?? String(localized: "debug.value.none")
    }
}

extension Optional where Wrapped == String {
    var nonEmptyDisplay: String {
        self?.trimmedOrNil ?? String(localized: "debug.value.none")
    }
}

extension CaptureArtifactDraft {
    var debugKindLabel: String {
        switch content {
        case .text: String(localized: "capture.type.text")
        case .photo: String(localized: "capture.type.photo")
        case .audio: String(localized: "capture.type.audio")
        case .video: "Video"
        case .livePhoto: "Live Photo"
        case .location: String(localized: "capture.type.location")
        case .link: String(localized: "capture.type.link")
        case .todo: String(localized: "capture.type.todo")
        case .promptAnswer: "Prompt"
        case .personContext: "Person"
        case .weather: String(localized: "capture.type.weather")
        case .music: String(localized: "capture.type.music")
        }
    }
}

// MARK: - Pretty JSON Helper

func prettyJSON(_ raw: String) -> String {
    guard let data = raw.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data),
          let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
          let result = String(data: pretty, encoding: .utf8)
    else {
        return raw
    }
    return result
}
