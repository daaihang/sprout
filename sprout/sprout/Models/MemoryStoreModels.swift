import Foundation
import SwiftData

@Model
final class ArtifactStoreModel {
    var id: UUID = UUID()
    var recordID: UUID = UUID()
    var kindRawValue: String = ArtifactKind.text.rawValue
    var title: String = ""
    var summary: String = ""
    var textContent: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    @Attribute(.externalStorage) var metadataData: Data = Data()
    @Attribute(.externalStorage) var entitiesData: Data = Data()
    @Attribute(.externalStorage) var binaryPayload: Data? = nil
    @Attribute(.externalStorage) var previewPayload: Data? = nil

    init() {}
}

@Model
final class RecordAnalysisSnapshotStoreModel {
    var id: UUID = UUID()
    var recordID: UUID = UUID()
    var summary: String = ""
    @Attribute(.externalStorage) var themesData: Data = Data()
    var emotionInterpretation: String = ""
    @Attribute(.externalStorage) var followUpCandidatesData: Data = Data()
    @Attribute(.externalStorage) var entityMentionsData: Data = Data()
    var salienceScore: Double? = nil
    @Attribute(.externalStorage) var retrievalTermsData: Data = Data()
    var reflectionHint: String? = nil
    @Attribute(.externalStorage) var candidateEdgesData: Data = Data()
    var createdAt: Date = Date()

    init() {}
}

@Model
final class ReflectionSnapshotStoreModel {
    var id: UUID = UUID()
    var typeRawValue: String = ReflectionType.record.rawValue
    var title: String = ""
    var bodyText: String = ""
    var evidenceSummary: String? = nil
    var confidence: Double? = nil
    var statusRawValue: String = ReflectionStatus.active.rawValue
    var linkedTemporalArcID: UUID? = nil
    @Attribute(.externalStorage) var sourceRecordIDsData: Data = Data()
    @Attribute(.externalStorage) var sourceArtifactIDsData: Data = Data()
    @Attribute(.externalStorage) var sourceEntityIDsData: Data = Data()
    var createdAt: Date = Date()
    var savedAt: Date? = nil
    var dismissedAt: Date? = nil

    init() {}
}

@Model
final class EntityNodeStoreModel {
    var id: UUID = UUID()
    var kindRawValue: String = EntityKind.person.rawValue
    var displayName: String = ""
    var canonicalName: String = ""
    var summary: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var confidence: Double? = nil

    init() {}
}

@Model
final class EntityEdgeStoreModel {
    var id: UUID = UUID()
    var fromEntityID: UUID = UUID()
    var toEntityID: UUID = UUID()
    var relationKindRawValue: String = EntityRelationKind.relatedTo.rawValue
    var weight: Double = 1
    var firstSeenAt: Date = Date()
    var lastSeenAt: Date = Date()
    var evidenceCount: Int = 1
    @Attribute(.externalStorage) var sourceArtifactIDsData: Data = Data()
    @Attribute(.externalStorage) var sourceRecordIDsData: Data = Data()

    init() {}
}

@Model
final class ArtifactEntityLinkStoreModel {
    var id: UUID = UUID()
    var artifactID: UUID = UUID()
    var entityID: UUID = UUID()
    var confidence: Double? = nil
    var source: String = ""
    var createdAt: Date = Date()

    init() {}
}

@Model
final class TemporalArcStoreModel {
    var id: UUID = UUID()
    var title: String = ""
    var summary: String = ""
    var statusRawValue: String = TemporalArcStatus.candidate.rawValue
    var dominantTheme: String? = nil
    var dominantEntityName: String? = nil
    @Attribute(.externalStorage) var themeLabelsData: Data = Data()
    @Attribute(.externalStorage) var entityNamesData: Data = Data()
    var linkedReflectionID: UUID? = nil
    @Attribute(.externalStorage) var mergedFromArcIDsData: Data = Data()
    var mergedIntoArcID: UUID? = nil
    var lastMergedAt: Date? = nil
    @Attribute(.externalStorage) var sourceRecordIDsData: Data = Data()
    @Attribute(.externalStorage) var sourceArtifactIDsData: Data = Data()
    @Attribute(.externalStorage) var sourceEntityIDsData: Data = Data()
    var startDate: Date = Date()
    var endDate: Date = Date()
    var intensityScore: Double = 0
    var clusterStrength: Double = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init() {}
}

enum MemoryModelSchema {
    static var allModels: [any PersistentModel.Type] {
        [
            Record.self,
            Board.self,
            Composition.self,
            CompositionItem.self,
            DashboardSystemCardConfig.self,
            ArtifactStoreModel.self,
            RecordAnalysisSnapshotStoreModel.self,
            ReflectionSnapshotStoreModel.self,
            EntityNodeStoreModel.self,
            EntityEdgeStoreModel.self,
            ArtifactEntityLinkStoreModel.self,
            TemporalArcStoreModel.self,
        ]
    }

    static func makeSchema() -> Schema {
        Schema(allModels)
    }
}
