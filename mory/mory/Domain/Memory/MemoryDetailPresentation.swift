import Foundation

enum MemoryDetailPresentationMode: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case story
    case text
    case gallery
    case audio
    case checkIn
    case link
    case article

    var id: String { rawValue }
}

enum MemoryDetailPresentationStrategy: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case ruleBased
    case fixed
    case aiAutomatic

    var id: String { rawValue }

    static var userVisibleCases: [MemoryDetailPresentationStrategy] {
        [.ruleBased, .fixed]
    }
}

struct MemoryDetailPresentationPreference: Identifiable, Codable, Hashable, Sendable {
    static let schemaVersion = 1

    var id: UUID
    var recordID: UUID
    var schemaVersion: Int
    var mode: MemoryDetailPresentationMode
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        recordID: UUID,
        schemaVersion: Int = MemoryDetailPresentationPreference.schemaVersion,
        mode: MemoryDetailPresentationMode,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.recordID = recordID
        self.schemaVersion = schemaVersion
        self.mode = mode
        self.updatedAt = updatedAt
    }
}

struct MemoryDetailPresentationSnapshot: Hashable, Sendable {
    var mode: MemoryDetailPresentationMode
    var record: RecordShell
    var bodyText: String
    var title: String
    var subtitle: String
    var contentArtifacts: [Artifact]
    var contextArtifacts: [Artifact]
    var textArtifacts: [Artifact]
    var photoArtifacts: [Artifact]
    var audioArtifacts: [Artifact]
    var linkArtifacts: [Artifact]
    var articleArtifacts: [Artifact]
    var analysis: RecordAnalysisSnapshot?
    var pipelineStatus: MemoryPipelineStatusSnapshot?
    var entities: [EntityNode]
    var edges: [EntityEdge]
    var arcs: [TemporalArc]
    var reflections: [ReflectionSnapshot]
}
