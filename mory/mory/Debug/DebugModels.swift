import Foundation
import SwiftData

// MARK: - Debug Analysis Target

enum DebugAnalysisTarget: String, CaseIterable, Identifiable, Sendable {
    case memory
    case arc
    case reflection

    var id: String { rawValue }
}

// MARK: - Debug Rebuild Mode

enum DebugRebuildMode: Sendable {
    case analysisOnly
    case graphArcReflection
    case reflectionReplay
}

// MARK: - Debug Pipeline Trace Snapshot

struct DebugPipelineTraceSnapshot: Sendable {
    let requestBody: String?
    let responseBody: String?
    let rawErrorBody: String?
    let statusCode: Int?
    let failedStage: String?
}

// MARK: - Debug Memory Fixture Snapshot

struct DebugMemoryFixtureSnapshot: Sendable {
    let recordID: UUID
    let recordTitle: String
    let chain: DebugMemoryChainSnapshot
}

// MARK: - Debug Memory Chain Snapshot

struct DebugMemoryChainSnapshot: Sendable {
    let record: RecordShell
    let artifacts: [Artifact]
    let analysis: RecordAnalysisSnapshot?
    let pipelineStatus: MemoryPipelineStatusSnapshot?
    let entities: [EntityNode]
    let edges: [EntityEdge]
    let links: [ArtifactEntityLink]
    let arcs: [TemporalArc]
    let reflections: [ReflectionSnapshot]
}

// MARK: - Debug Target Snapshot

struct DebugTargetSnapshot: Sendable {
    let targetType: DebugAnalysisTarget
    let memory: MemorySummary?
    let arc: TemporalArcSummarySnapshot?
    let reflection: ReflectionSummarySnapshot?
}

// MARK: - Debug Diagnostics Snapshot

struct DebugDiagnosticsSnapshot: Sendable {
    let target: DebugTargetSnapshot?
    let analyzePayload: DebugAnalyzePayloadSnapshot?
    let reflectionPayload: DebugReflectionPayloadSnapshot?
    let provenance: [DebugProvenanceSnapshot]
    let fixture: DebugMemoryFixtureSnapshot?
    let pipelineTrace: DebugPipelineTraceSnapshot?
}

// MARK: - Debug Provenance Snapshot

struct DebugProvenanceSnapshot: Identifiable, Sendable {
    let entityID: UUID
    let aliasCount: Int
    let provenanceRecordIDs: [UUID]
    let linkedArtifactIDs: [UUID]
    let linkedAnalysisRecordIDs: [UUID]
    let evidenceSummary: String

    var id: UUID { entityID }
}

// MARK: - Debug Analyze Payload Snapshot

struct DebugAnalyzePayloadSnapshot: Sendable {
    let recordID: UUID
    let requestBody: String
    let responseBody: String
    let lastError: String?
    let rawErrorBody: String?
}

// MARK: - Debug Reflection Payload Snapshot

struct DebugReflectionPayloadSnapshot: Sendable {
    let recordID: UUID?
    let arcID: UUID?
    let requestBody: String
    let responseBody: String
    let lastError: String?
    let rawErrorBody: String?
}

// MARK: - Reflection Service Result

struct ReflectionServiceResult: Sendable {
    let title: String
    let body: String
    let evidenceSummary: String
    let confidence: Double
    let sourceRecordIDs: [UUID]
    let debugTrace: DebugPipelineTraceSnapshot?
}