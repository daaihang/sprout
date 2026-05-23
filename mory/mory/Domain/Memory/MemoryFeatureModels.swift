import Foundation

enum UserSettingsAppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

enum UserSettingsContextSelection: String, CaseIterable, Identifiable, Codable, Sendable {
    case allAvailable
    case locationWeatherOnly
    case manual

    var id: String { rawValue }
}

enum UserSettingsInsightFrequency: String, CaseIterable, Identifiable, Codable, Sendable {
    case low
    case balanced
    case high

    var id: String { rawValue }
}

enum UserSettingsPromptTone: String, CaseIterable, Identifiable, Codable, Sendable {
    case concise
    case balanced
    case reflective

    var id: String { rawValue }
}

struct UserSettingsPreference: Identifiable, Codable, Hashable, Sendable {
    static let schemaVersion = 2
    static let defaultSyncKey = "user-settings-default"

    var id: UUID
    var syncKey: String
    var schemaVersion: Int
    var updatedAt: Date
    var appearanceMode: UserSettingsAppearanceMode
    var voiceLanguageIdentifier: String?
    var linkAutoDetectEnabled: Bool
    var defaultContextSelection: UserSettingsContextSelection
    var insightFrequency: UserSettingsInsightFrequency
    var promptTone: UserSettingsPromptTone
    var detailPresentationStrategy: MemoryDetailPresentationStrategy
    var fixedDetailPresentationMode: MemoryDetailPresentationMode

    init(
        id: UUID = UUID(),
        syncKey: String = UserSettingsPreference.defaultSyncKey,
        schemaVersion: Int = UserSettingsPreference.schemaVersion,
        updatedAt: Date = .now,
        appearanceMode: UserSettingsAppearanceMode = .system,
        voiceLanguageIdentifier: String? = nil,
        linkAutoDetectEnabled: Bool = true,
        defaultContextSelection: UserSettingsContextSelection = .allAvailable,
        insightFrequency: UserSettingsInsightFrequency = .balanced,
        promptTone: UserSettingsPromptTone = .balanced,
        detailPresentationStrategy: MemoryDetailPresentationStrategy = .ruleBased,
        fixedDetailPresentationMode: MemoryDetailPresentationMode = .story
    ) {
        self.id = id
        self.syncKey = syncKey
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.appearanceMode = appearanceMode
        self.voiceLanguageIdentifier = voiceLanguageIdentifier
        self.linkAutoDetectEnabled = linkAutoDetectEnabled
        self.defaultContextSelection = defaultContextSelection
        self.insightFrequency = insightFrequency
        self.promptTone = promptTone
        self.detailPresentationStrategy = detailPresentationStrategy
        self.fixedDetailPresentationMode = fixedDetailPresentationMode
    }

    static var defaults: UserSettingsPreference {
        UserSettingsPreference()
    }
}

enum CaptureArtifactOrigin: String, Codable, Hashable, Sendable, CaseIterable {
    case manual
    case context
    case imported
    case inferred
}

struct MusicArtworkPalette: Codable, Hashable, Sendable {
    let backgroundColorHex: String?
    let primaryTextColorHex: String?
    let secondaryTextColorHex: String?

    nonisolated init(
        backgroundColorHex: String? = nil,
        primaryTextColorHex: String? = nil,
        secondaryTextColorHex: String? = nil
    ) {
        self.backgroundColorHex = backgroundColorHex
        self.primaryTextColorHex = primaryTextColorHex
        self.secondaryTextColorHex = secondaryTextColorHex
    }

    nonisolated var isEmpty: Bool {
        backgroundColorHex == nil && primaryTextColorHex == nil && secondaryTextColorHex == nil
    }

    nonisolated var metadata: [String: String] {
        var metadata: [String: String] = [:]
        if let backgroundColorHex { metadata["artworkBackgroundColor"] = backgroundColorHex }
        if let primaryTextColorHex { metadata["artworkPrimaryTextColor"] = primaryTextColorHex }
        if let secondaryTextColorHex { metadata["artworkSecondaryTextColor"] = secondaryTextColorHex }
        return metadata
    }
}

struct ArtifactOriginRepairKindCount: Identifiable, Hashable, Sendable {
    let kind: ArtifactKind
    let count: Int

    var id: ArtifactKind { kind }
}

struct ArtifactOriginRepairPreview: Hashable, Sendable {
    let totalArtifactCount: Int
    let missingOriginCount: Int
    let kindCounts: [ArtifactOriginRepairKindCount]
    let generatedAt: Date
}

struct ArtifactOriginRepairResult: Hashable, Sendable {
    let repairedCount: Int
    let origin: CaptureArtifactOrigin
    let repairedArtifactIDs: [UUID]
    let generatedAt: Date
}

enum CaptureArtifactDraft: Hashable, Sendable, Identifiable {
    case text(title: String?, body: String, origin: CaptureArtifactOrigin = .manual)
    case photo(title: String?, summary: String, filename: String, imageData: Data?, thumbnailData: Data?, ocrText: String = "", photoMetadata: [String: String] = [:], origin: CaptureArtifactOrigin = .manual)
    case audio(title: String?, summary: String, filename: String, audioData: Data?, transcriptionText: String = "", origin: CaptureArtifactOrigin = .manual)
    case location(title: String?, summary: String, latitude: Double?, longitude: Double?, origin: CaptureArtifactOrigin = .manual)
    case link(title: String?, url: String, note: String?, summary: String? = nil, metadata: [String: String] = [:], thumbnailData: Data? = nil, origin: CaptureArtifactOrigin = .manual)
    case todo(title: String, note: String?, origin: CaptureArtifactOrigin = .manual)
    case weather(condition: String, temperatureCelsius: Double, humidity: Double, windSpeedKmh: Double, uvIndex: Int, latitude: Double? = nil, longitude: Double? = nil, conditionCode: String? = nil, symbolName: String? = nil, isDaylight: Bool? = nil, origin: CaptureArtifactOrigin = .manual)
    case music(trackName: String, artistName: String, albumName: String, durationSeconds: Int, artworkURL: String?, artworkData: Data? = nil, artworkPalette: MusicArtworkPalette? = nil, origin: CaptureArtifactOrigin = .manual)

    var id: String {
        switch self {
        case let .text(title, body, _):
            return "text-\(title ?? body)"
        case let .photo(title, summary, filename, _, _, _, _, _):
            return "photo-\(title ?? summary)-\(filename)"
        case let .audio(title, summary, filename, _, _, _):
            return "audio-\(title ?? summary)-\(filename)"
        case let .location(title, summary, _, _, _):
            return "location-\(title ?? summary)"
        case let .link(title, url, _, _, _, _, _):
            return "link-\(title ?? url)"
        case let .todo(title, note, _):
            return "todo-\(title)-\(note ?? "")"
        case let .weather(condition, temp, _, _, _, _, _, _, _, _, _):
            return "weather-\(condition)-\(temp)"
        case let .music(trackName, artistName, _, _, _, _, _, _):
            return "music-\(trackName)-\(artistName)"
        }
    }

    var captureSummary: String {
        switch self {
        case let .text(title, body, _):
            return [title?.trimmedOrNil, body.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? body.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? "Untitled Memory"
        case let .photo(title, summary, filename, _, _, _, _, _):
            return [title?.trimmedOrNil, summary.trimmedOrNil, filename.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? summary.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? filename
        case let .audio(title, summary, filename, _, _, _):
            return [title?.trimmedOrNil, summary.trimmedOrNil, filename.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? summary.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? filename
        case let .location(title, summary, latitude, longitude, _):
            var components = [title?.trimmedOrNil, summary.trimmedOrNil].compactMap { $0 }
            if let latitude {
                components.append(String(latitude))
            }
            if let longitude {
                components.append(String(longitude))
            }
            return components.joined(separator: " • ").trimmedOrNil
                ?? summary.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? "Location capture"
        case let .link(title, url, note, summary, _, _, _):
            return [title?.trimmedOrNil, summary?.trimmedOrNil, note?.trimmedOrNil, url.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? summary?.trimmedOrNil
                ?? note?.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? url
        case let .todo(title, note, _):
            return [title.trimmedOrNil, note?.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? note?.trimmedOrNil
                ?? title
        case let .weather(condition, temp, humidity, _, _, _, _, _, _, _, _):
            return "\(condition) \(String(format: "%.0f", temp))°C · Humidity \(String(format: "%.0f", humidity * 100))%"
        case let .music(trackName, artistName, albumName, _, _, _, _, _):
            return [trackName, artistName, albumName].filter { !$0.isEmpty }.joined(separator: " · ")
        }
    }

    var origin: CaptureArtifactOrigin {
        switch self {
        case let .text(_, _, origin):
            return origin
        case let .photo(_, _, _, _, _, _, _, origin):
            return origin
        case let .audio(_, _, _, _, _, origin):
            return origin
        case let .location(_, _, _, _, origin):
            return origin
        case let .link(_, _, _, _, _, _, origin):
            return origin
        case let .todo(_, _, origin):
            return origin
        case let .weather(_, _, _, _, _, _, _, _, _, _, origin):
            return origin
        case let .music(_, _, _, _, _, _, _, origin):
            return origin
        }
    }

    func withOrigin(_ origin: CaptureArtifactOrigin) -> CaptureArtifactDraft {
        switch self {
        case let .text(title, body, _):
            return .text(title: title, body: body, origin: origin)
        case let .photo(title, summary, filename, imageData, thumbnailData, ocrText, photoMetadata, _):
            return .photo(
                title: title,
                summary: summary,
                filename: filename,
                imageData: imageData,
                thumbnailData: thumbnailData,
                ocrText: ocrText,
                photoMetadata: photoMetadata,
                origin: origin
            )
        case let .audio(title, summary, filename, audioData, transcriptionText, _):
            return .audio(
                title: title,
                summary: summary,
                filename: filename,
                audioData: audioData,
                transcriptionText: transcriptionText,
                origin: origin
            )
        case let .location(title, summary, latitude, longitude, _):
            return .location(
                title: title,
                summary: summary,
                latitude: latitude,
                longitude: longitude,
                origin: origin
            )
        case let .link(title, url, note, summary, metadata, thumbnailData, _):
            return .link(
                title: title,
                url: url,
                note: note,
                summary: summary,
                metadata: metadata,
                thumbnailData: thumbnailData,
                origin: origin
            )
        case let .todo(title, note, _):
            return .todo(title: title, note: note, origin: origin)
        case let .weather(condition, temperatureCelsius, humidity, windSpeedKmh, uvIndex, latitude, longitude, conditionCode, symbolName, isDaylight, _):
            return .weather(
                condition: condition,
                temperatureCelsius: temperatureCelsius,
                humidity: humidity,
                windSpeedKmh: windSpeedKmh,
                uvIndex: uvIndex,
                latitude: latitude,
                longitude: longitude,
                conditionCode: conditionCode,
                symbolName: symbolName,
                isDaylight: isDaylight,
                origin: origin
            )
        case let .music(trackName, artistName, albumName, durationSeconds, artworkURL, artworkData, artworkPalette, _):
            return .music(
                trackName: trackName,
                artistName: artistName,
                albumName: albumName,
                durationSeconds: durationSeconds,
                artworkURL: artworkURL,
                artworkData: artworkData,
                artworkPalette: artworkPalette,
                origin: origin
            )
        }
    }
}

struct MemoryCaptureDraft: Hashable, Sendable {
    var title: String?
    var rawText: String
    var mood: String?
    var inputContext: String?
    var captureSource: CaptureSource
    var artifacts: [CaptureArtifactDraft]
    var affectSnapshots: [AffectSnapshotDraft]

    init(
        title: String? = nil,
        rawText: String,
        mood: String? = nil,
        inputContext: String? = nil,
        captureSource: CaptureSource = .composer,
        artifacts: [CaptureArtifactDraft] = [],
        affectSnapshots: [AffectSnapshotDraft] = []
    ) {
        self.title = title
        self.rawText = rawText
        self.mood = mood
        self.inputContext = inputContext
        self.captureSource = captureSource
        self.artifacts = artifacts
        self.affectSnapshots = affectSnapshots
    }
}

struct MemorySummary: Identifiable, Hashable, Sendable {
    let record: RecordShell
    let primaryArtifact: Artifact?
    let contextArtifacts: [Artifact]
    let artifactCount: Int
    let pipelineStatus: MemoryPipelineStatusSnapshot?

    var id: UUID { record.id }

    var title: String {
        if let artifactTitle = primaryArtifact?.title.trimmedOrNil {
            return artifactTitle
        }
        return record.rawText.firstMeaningfulLine ?? "Untitled Memory"
    }

    var summaryText: String {
        if let artifactSummary = primaryArtifact?.summary.trimmedOrNil {
            return artifactSummary
        }
        return record.rawText.trimmedOrNil ?? "No summary yet"
    }
}

struct MemoryDetailSnapshot: Hashable, Sendable {
    let record: RecordShell
    let artifacts: [Artifact]
    let analysis: RecordAnalysisSnapshot?
    let pipelineStatus: MemoryPipelineStatusSnapshot?
    let entities: [EntityNode]
    let edges: [EntityEdge]
    let arcs: [TemporalArc]
    let reflections: [ReflectionSnapshot]
}

struct MemoryEditDraft: Hashable, Sendable {
    var rawText: String
    var userMood: String?
    var inputContext: String?
    var appendedArtifactText: String?

    init(
        rawText: String,
        userMood: String? = nil,
        inputContext: String? = nil,
        appendedArtifactText: String? = nil
    ) {
        self.rawText = rawText
        self.userMood = userMood
        self.inputContext = inputContext
        self.appendedArtifactText = appendedArtifactText
    }
}

enum MemoryMutationField<Value: Hashable & Sendable>: Hashable, Sendable {
    case unchanged
    case set(Value?)

    var shouldUpdate: Bool {
        if case .set = self { true } else { false }
    }

    var value: Value? {
        if case let .set(value) = self { value } else { nil }
    }
}

struct MemoryMutationRecordPatch: Hashable, Sendable {
    var rawText: MemoryMutationField<String>
    var userMood: MemoryMutationField<String>
    var inputContext: MemoryMutationField<String>
    var captureSource: MemoryMutationField<CaptureSource>

    init(
        rawText: MemoryMutationField<String> = .unchanged,
        userMood: MemoryMutationField<String> = .unchanged,
        inputContext: MemoryMutationField<String> = .unchanged,
        captureSource: MemoryMutationField<CaptureSource> = .unchanged
    ) {
        self.rawText = rawText
        self.userMood = userMood
        self.inputContext = inputContext
        self.captureSource = captureSource
    }

    var hasChanges: Bool {
        rawText.shouldUpdate
            || userMood.shouldUpdate
            || inputContext.shouldUpdate
            || captureSource.shouldUpdate
    }
}

struct MemoryMutationDraft: Hashable, Sendable {
    var recordPatch: MemoryMutationRecordPatch
    var addedArtifacts: [CaptureArtifactDraft]
    var updatedArtifacts: [Artifact]
    var deletedArtifactIDs: [UUID]
    var artifactOrder: [UUID]?

    init(
        recordPatch: MemoryMutationRecordPatch = MemoryMutationRecordPatch(),
        addedArtifacts: [CaptureArtifactDraft] = [],
        updatedArtifacts: [Artifact] = [],
        deletedArtifactIDs: [UUID] = [],
        artifactOrder: [UUID]? = nil
    ) {
        self.recordPatch = recordPatch
        self.addedArtifacts = addedArtifacts
        self.updatedArtifacts = updatedArtifacts
        self.deletedArtifactIDs = deletedArtifactIDs
        self.artifactOrder = artifactOrder
    }

    var hasChanges: Bool {
        recordPatch.hasChanges
            || !addedArtifacts.isEmpty
            || !updatedArtifacts.isEmpty
            || !deletedArtifactIDs.isEmpty
            || artifactOrder != nil
    }
}

enum MemoryMutationRefreshPolicy: Hashable, Sendable {
    case markPending
    case runImmediately
}

struct MemoryMutationResult: Hashable, Sendable {
    let mutationID: UUID
    let detail: MemoryDetailSnapshot?
    let addedArtifactIDs: [UUID]
    let updatedArtifactIDs: [UUID]
    let deletedArtifactIDs: [UUID]
    let reorderedArtifactIDs: [UUID]
    let invalidatedDerivedData: Bool
    let pipelineStatus: MemoryPipelineStatusSnapshot?
}

enum MemoryPipelineStage: String, Codable, CaseIterable, Identifiable, Sendable {
    case pending
    case running
    case completed
    case failed

    var id: String { rawValue }
}

struct MemoryPipelineStatusSnapshot: Identifiable, Hashable, Sendable {
    let recordID: UUID
    let stage: MemoryPipelineStage
    let requestID: String?
    let lastError: String?
    let requestBody: String?
    let responseBody: String?
    let rawErrorBody: String?
    let lastHTTPStatusCode: Int?
    let failedStage: String?
    let lastAttemptAt: Date?
    let completedAt: Date?
    let updatedAt: Date

    var id: UUID { recordID }

    var userLabel: String {
        switch stage {
        case .pending:
            return String(localized: "pipeline.status.pending")
        case .running:
            return String(localized: "pipeline.status.running")
        case .completed:
            return String(localized: "pipeline.status.completed")
        case .failed:
            return String(localized: "pipeline.status.failed")
        }
    }

    var explanation: String {
        switch stage {
        case .pending:
            return String(localized: "pipeline.explain.pending")
        case .running:
            return String(localized: "pipeline.explain.running")
        case .completed:
            return String(localized: "pipeline.explain.completed")
        case .failed:
            return String(localized: "pipeline.explain.failed")
        }
    }
}

enum CompositionRenderValue: Hashable, Sendable {
    case memory(MemorySummary)
    case arc(TemporalArc)
    case reflection(ReflectionSnapshot)
    case clarificationQuestion(question: ClarificationQuestion, profile: EntityProfile?)
    case yesterdayPanel(title: String, subtitle: String, sourceRecordIDs: [UUID])
    case systemPrompt(title: String, subtitle: String, actionTitle: String?)
    case contextCluster(title: String, subtitle: String, sourceRecordIDs: [UUID])
    case pendingAction(title: String, subtitle: String, targetRecordID: UUID?)
}

struct HomeBoardItemSnapshot: Identifiable, Hashable, Sendable {
    let compositionItem: CompositionItem
    let renderValue: CompositionRenderValue
    let cardKind: HomeBoardCardKind
    let priority: Double
    let reason: String
    let sourceRecordIDs: [UUID]
    let layout: HomeBoardItemLayout
    let isPinned: Bool
    let isHidden: Bool
    let dismissedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    var id: UUID { compositionItem.id }
}

struct HomeBoardSnapshot: Hashable, Sendable {
    let board: Board
    let composition: Composition
    let items: [HomeBoardItemSnapshot]

    var userBoardItems: [HomeBoardItemSnapshot] {
        items.filter { $0.layout.layer == .userBoard }
    }

    var suggestionItems: [HomeBoardItemSnapshot] {
        items.filter { $0.layout.layer == .suggestion }
    }
}

struct HomeBoardDebugInputSnapshot: Hashable, Sendable {
    let memoryCount: Int
    let todayMemoryCount: Int
    let recent24HourMemoryCount: Int
    let contextMemoryCount: Int
    let highSalienceMemoryCount: Int
    let graphLinkCount: Int
    let entityCount: Int
    let edgeCount: Int
    let acceptedArcCount: Int
    let activeAcceptedArcCount: Int
    let suggestedReflectionCount: Int
    let savedReflectionCount: Int
    let runningPipelineCount: Int
    let failedPipelineCount: Int
}

struct HomeBoardDebugPreferenceSnapshot: Hashable, Sendable {
    let totalCount: Int
    let pinnedCount: Int
    let hiddenCount: Int
    let dismissedCount: Int
}

struct HomeBoardDebugSnapshot: Hashable, Sendable {
    let generatedAt: Date
    let date: Date
    let limit: Int
    let input: HomeBoardDebugInputSnapshot
    let preferences: HomeBoardDebugPreferenceSnapshot
    let board: HomeBoardSnapshot
}

enum MemoryLibraryContextFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case any
    case hasLocation
    case hasWeather
    case hasMusic

    var id: String { rawValue }
}

enum MemoryLibraryInsightFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case any
    case hasStoryline
    case hasReflection
    case hasEntities

    var id: String { rawValue }
}

struct MemoryLibraryFilter: Hashable, Sendable {
    var dateRange: ClosedRange<Date>?
    var artifactKinds: Set<ArtifactKind>
    var pipelineStages: Set<MemoryPipelineStage>
    var context: MemoryLibraryContextFilter
    var insight: MemoryLibraryInsightFilter

    init(
        dateRange: ClosedRange<Date>? = nil,
        artifactKinds: Set<ArtifactKind> = [],
        pipelineStages: Set<MemoryPipelineStage> = [],
        context: MemoryLibraryContextFilter = .any,
        insight: MemoryLibraryInsightFilter = .any
    ) {
        self.dateRange = dateRange
        self.artifactKinds = artifactKinds
        self.pipelineStages = pipelineStages
        self.context = context
        self.insight = insight
    }

    static var empty: MemoryLibraryFilter { MemoryLibraryFilter() }

    var isActive: Bool {
        dateRange != nil || !artifactKinds.isEmpty || !pipelineStages.isEmpty || context != .any || insight != .any
    }
}

struct MemoryLibraryRowSnapshot: Identifiable, Hashable, Sendable {
    let memory: MemorySummary
    let artifactKinds: [ArtifactKind]
    let hasLocation: Bool
    let hasWeather: Bool
    let hasMusic: Bool
    let relatedStorylineCount: Int
    let relatedReflectionCount: Int
    let entityCount: Int

    var id: UUID { memory.id }
    var hasContext: Bool { hasLocation || hasWeather || hasMusic }
    var hasInsights: Bool { relatedStorylineCount > 0 || relatedReflectionCount > 0 || entityCount > 0 }
}

struct MemoryLibraryDayGroup: Identifiable, Hashable, Sendable {
    let date: Date
    let rows: [MemoryLibraryRowSnapshot]

    var id: Date { date }
    var dayLabel: String { date.formatted(date: .abbreviated, time: .omitted) }
}

struct MemoryLibraryFilterMetadata: Hashable, Sendable {
    let availableArtifactKinds: [ArtifactKind]
    let availablePipelineStages: [MemoryPipelineStage]
    let contextMemoryCount: Int
    let insightMemoryCount: Int
}

struct MemoryLibrarySnapshot: Hashable, Sendable {
    let filter: MemoryLibraryFilter
    let groups: [MemoryLibraryDayGroup]
    let totalCount: Int
    let filteredCount: Int
    let metadata: MemoryLibraryFilterMetadata
}

struct PersonMemorySummary: Identifiable, Hashable, Sendable {
    let entity: EntityNode
    let artifactCount: Int
    let relatedMemories: [MemorySummary]
    let themeLabels: [String]
    let reflectionCount: Int

    var id: UUID { entity.id }
}

struct ThemeMemorySummary: Identifiable, Hashable, Sendable {
    let entity: EntityNode
    let artifactCount: Int
    let relatedMemories: [MemorySummary]
    let relatedPeople: [String]
    let arcCount: Int

    var id: UUID { entity.id }
}

struct EntityDetailSnapshot: Identifiable, Hashable, Sendable {
    let entity: EntityNode
    let artifactCount: Int
    let relatedMemories: [MemorySummary]
    let relatedThemes: [String]
    let relatedPeople: [String]
    let relatedReflections: [ReflectionSummarySnapshot]
    let relatedArcs: [TemporalArcSummarySnapshot]
    let edges: [EntityEdge]
    let intelligenceProfile: EntityProfile?
    let pendingQuestions: [ClarificationQuestion]

    init(
        entity: EntityNode,
        artifactCount: Int,
        relatedMemories: [MemorySummary],
        relatedThemes: [String],
        relatedPeople: [String],
        relatedReflections: [ReflectionSummarySnapshot],
        relatedArcs: [TemporalArcSummarySnapshot],
        edges: [EntityEdge],
        intelligenceProfile: EntityProfile? = nil,
        pendingQuestions: [ClarificationQuestion] = []
    ) {
        self.entity = entity
        self.artifactCount = artifactCount
        self.relatedMemories = relatedMemories
        self.relatedThemes = relatedThemes
        self.relatedPeople = relatedPeople
        self.relatedReflections = relatedReflections
        self.relatedArcs = relatedArcs
        self.edges = edges
        self.intelligenceProfile = intelligenceProfile
        self.pendingQuestions = pendingQuestions
    }

    var id: UUID { entity.id }
}

enum PlaceProfileMutationError: LocalizedError, Equatable {
    case profileNotFound
    case emptyDisplayName
    case mergeRequiresAtLeastOneOtherProfile
    case mergeCannotIncludePrimary
    case splitRequiresMovingArtifacts
    case splitCannotMoveAllArtifacts
    case splitArtifactsNotInProfile
    case splitArtifactsMustBeLocations

    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            "Place profile was not found."
        case .emptyDisplayName:
            "Place name cannot be empty."
        case .mergeRequiresAtLeastOneOtherProfile:
            "Choose at least one other place to merge."
        case .mergeCannotIncludePrimary:
            "A place cannot be merged into itself."
        case .splitRequiresMovingArtifacts:
            "Choose at least one location artifact to split."
        case .splitCannotMoveAllArtifacts:
            "A split must leave at least one location artifact in the original place."
        case .splitArtifactsNotInProfile:
            "Selected artifacts are not linked to this place."
        case .splitArtifactsMustBeLocations:
            "Only location artifacts can be split into a place profile."
        }
    }
}

enum PersonEntityMutationError: LocalizedError, Equatable {
    case entityNotFound
    case entityIsNotPerson
    case emptyDisplayName
    case mergeRequiresAtLeastOneOtherEntity
    case mergeCannotIncludePrimary
    case splitRequiresMovingRecords
    case splitCannotMoveAllRecords
    case splitRecordsNotInEntity

    var errorDescription: String? {
        switch self {
        case .entityNotFound:
            "Person entity was not found."
        case .entityIsNotPerson:
            "Selected entity is not a person."
        case .emptyDisplayName:
            "Person name cannot be empty."
        case .mergeRequiresAtLeastOneOtherEntity:
            "Choose at least one other person to merge."
        case .mergeCannotIncludePrimary:
            "A person cannot be merged into itself."
        case .splitRequiresMovingRecords:
            "Choose at least one source memory to split."
        case .splitCannotMoveAllRecords:
            "A split must leave at least one memory on the original person."
        case .splitRecordsNotInEntity:
            "Selected memories are not linked to this person."
        }
    }
}

struct SearchMemoryResultSnapshot: Identifiable, Hashable, Sendable {
    let memory: MemorySummary
    let explanations: [SearchMatchExplanation]

    init(memory: MemorySummary, explanations: [SearchMatchExplanation] = []) {
        self.memory = memory
        self.explanations = explanations
    }

    var id: UUID { memory.id }
}

struct SearchEntityResultSnapshot: Identifiable, Hashable, Sendable {
    let entity: EntityNode
    let artifactCount: Int
    let relatedMemoryCount: Int
    let relatedThemes: [String]
    let relatedPeople: [String]
    let reflectionCount: Int
    let arcCount: Int

    var id: UUID { entity.id }
}

struct SearchArcResultSnapshot: Identifiable, Hashable, Sendable {
    let summary: TemporalArcSummarySnapshot

    var id: UUID { summary.id }
}

struct SearchReflectionResultSnapshot: Identifiable, Hashable, Sendable {
    let summary: ReflectionSummarySnapshot

    var id: UUID { summary.id }
}

enum SearchRetrievalSource: String, Hashable, Sendable {
    case exactFallback
    case graph
    case spotlight
}

enum SearchMatchSource: String, Hashable, Sendable {
    case record
    case artifact
    case entity
    case context
    case spotlight
}

struct SearchMatchExplanation: Identifiable, Hashable, Sendable {
    var id: String {
        [
            source.rawValue,
            artifactID?.uuidString ?? "",
            entityID?.uuidString ?? "",
            label,
            snippet,
        ].joined(separator: "|")
    }

    let source: SearchMatchSource
    let label: String
    let snippet: String
    let artifactID: UUID?
    let entityID: UUID?

    init(
        source: SearchMatchSource,
        label: String,
        snippet: String,
        artifactID: UUID? = nil,
        entityID: UUID? = nil
    ) {
        self.source = source
        self.label = label
        self.snippet = snippet
        self.artifactID = artifactID
        self.entityID = entityID
    }
}

enum SemanticSearchStatus: Hashable, Sendable {
    case notRequested
    case disabled
    case unavailable
    case succeeded(resultCount: Int)
    case failed(String)
}

struct SearchSnapshot: Hashable, Sendable {
    var query: String
    var memories: [SearchMemoryResultSnapshot]
    var entities: [SearchEntityResultSnapshot]
    var arcs: [SearchArcResultSnapshot]
    var reflections: [SearchReflectionResultSnapshot]
    var semanticMemoryIDs: [UUID] = []
    var retrievalSources: [SearchRetrievalSource] = []
    var semanticSearchStatus: SemanticSearchStatus = .notRequested
}

struct SpotlightIndexReport: Hashable, Sendable {
    var indexedItemCount: Int
    var deletedItemCount: Int
    var skippedReason: String?

    static func skipped(_ reason: String) -> SpotlightIndexReport {
        SpotlightIndexReport(indexedItemCount: 0, deletedItemCount: 0, skippedReason: reason)
    }
}

struct GraphEntitySectionSnapshot: Identifiable, Hashable, Sendable {
    let kind: EntityKind
    let entities: [EntityNode]

    var id: String { kind.rawValue }
}

struct GraphOverviewSnapshot: Hashable, Sendable {
    let entitySections: [GraphEntitySectionSnapshot]
    let topEdges: [EntityEdge]
    let people: [PersonMemorySummary]
    let themes: [ThemeMemorySummary]
}

struct TemporalArcSummarySnapshot: Identifiable, Hashable, Sendable {
    let arc: TemporalArc
    let relatedMemories: [MemorySummary]
    let linkedReflection: ReflectionSnapshot?

    var id: UUID { arc.id }
}

struct ReflectionSummarySnapshot: Identifiable, Hashable, Sendable {
    let reflection: ReflectionSnapshot
    let linkedArc: TemporalArc?
    let relatedMemories: [MemorySummary]

    var id: UUID { reflection.id }
}

struct PersonDetailSnapshot: Identifiable, Hashable, Sendable {
    let summary: PersonMemorySummary
    let relatedArcs: [TemporalArcSummarySnapshot]
    let relatedReflections: [ReflectionSummarySnapshot]

    var id: UUID { summary.id }
}

struct TemporalArcDetailSnapshot: Identifiable, Hashable, Sendable {
    let summary: TemporalArcSummarySnapshot
    let reflections: [ReflectionSummarySnapshot]
    let entityDetails: [EntityDetailSnapshot]
    let mergeCandidate: TemporalArcSummarySnapshot?
    let mergeCandidateOverlapScore: Double?

    var id: UUID { summary.id }
}

struct ReflectionDetailSnapshot: Identifiable, Hashable, Sendable {
    let summary: ReflectionSummarySnapshot
    let linkedArc: TemporalArcSummarySnapshot?
    let entityDetails: [EntityDetailSnapshot]

    var id: UUID { summary.id }
}

struct PipelineStatusSummary: Identifiable, Hashable, Sendable {
    let recordID: UUID
    let title: String
    let status: MemoryPipelineStatusSnapshot

    var id: UUID { recordID }
}

struct InsightsPresentationSnapshot: Hashable, Sendable {
    let highlightedStoryline: TemporalArcSummarySnapshot?
    let storylines: [TemporalArcSummarySnapshot]
    let suggestedReflections: [ReflectionSummarySnapshot]
    let savedReflections: [ReflectionSummarySnapshot]
    let people: [EntityDetailSnapshot]
    let places: [EntityDetailSnapshot]
    let themes: [EntityDetailSnapshot]
    let decisions: [EntityDetailSnapshot]
    let topEdges: [EntityEdge]
    let totalStorylineCount: Int
    let totalReflectionCount: Int
    let totalEntityCount: Int
}

@MainActor
protocol MoryMemoryRepositorying: NotificationIntentRepositorying {
    func createMemory(from draft: MemoryCaptureDraft) async throws -> MemorySummary
    func applyMemoryMutation(recordID: UUID, mutation: MemoryMutationDraft, refreshPolicy: MemoryMutationRefreshPolicy) async throws -> MemoryMutationResult
    func appendArtifacts(recordID: UUID, drafts: [CaptureArtifactDraft]) async throws -> MemorySummary?
    func updateMemory(recordID: UUID, draft: MemoryEditDraft) async throws -> MemoryDetailSnapshot?
    func deleteMemory(recordID: UUID) throws
    func refreshMemoryPipeline(recordID: UUID) async throws
    func fetchRecentMemories(limit: Int?) throws -> [MemorySummary]
    func fetchMemoryLibrary(filter: MemoryLibraryFilter, limit: Int?) throws -> MemoryLibrarySnapshot
    func fetchTimeline(granularity: TimelineGranularity, limit: Int?) throws -> TimelineSnapshot
    func fetchHomeBoard(for date: Date, limit: Int) throws -> HomeBoardSnapshot
    func fetchHomeBoardDebugSnapshot(for date: Date, limit: Int) throws -> HomeBoardDebugSnapshot
    func updateHomeBoardItemPreference(_ item: HomeBoardItemSnapshot, action: HomeBoardPreferenceAction) throws
    func updateHomeBoardItemPreferences(_ updates: [(item: HomeBoardItemSnapshot, action: HomeBoardPreferenceAction)]) throws
    func fetchMemoryDetail(recordID: UUID) throws -> MemoryDetailSnapshot?
    func fetchArtifact(id: UUID) throws -> Artifact?
    func fetchArtifactOriginRepairPreview() throws -> ArtifactOriginRepairPreview
    func backfillMissingArtifactOrigins(_ origin: CaptureArtifactOrigin) throws -> ArtifactOriginRepairResult
    func fetchRecordAnalysis(recordID: UUID) throws -> RecordAnalysisSnapshot?
    func fetchPipelineStatus(recordID: UUID) throws -> MemoryPipelineStatusSnapshot?
    func fetchPipelineStatusSummaries(limit: Int?) throws -> [PipelineStatusSummary]
    func search(query: String, limit: Int?) throws -> SearchSnapshot
    func searchSemanticFirst(query: String, limit: Int?) async throws -> SearchSnapshot
    func rebuildSpotlightIndex() async throws -> SpotlightIndexReport
    func deleteSpotlightIndex() async throws -> SpotlightIndexReport
    func fetchEntityDetails(kind: EntityKind, limit: Int?) throws -> [EntityDetailSnapshot]
    func fetchEntityDetail(entityID: UUID) throws -> EntityDetailSnapshot?
    func fetchPeopleSummaries(limit: Int?) throws -> [PersonMemorySummary]
    func fetchPersonDetail(entityID: UUID) throws -> PersonDetailSnapshot?
    func fetchThemeSummaries(limit: Int?) throws -> [ThemeMemorySummary]
    func fetchGraphOverview(limitPerKind: Int?, edgeLimit: Int?) throws -> GraphOverviewSnapshot
    func fetchInsightsPresentation(limitPerSection: Int?) throws -> InsightsPresentationSnapshot
    func fetchTemporalArcs(limit: Int?) throws -> [TemporalArc]
    func fetchTemporalArcSummaries(limit: Int?) throws -> [TemporalArcSummarySnapshot]
    func fetchTemporalArcDetail(arcID: UUID) throws -> TemporalArcDetailSnapshot?
    func acceptTemporalArc(arcID: UUID) async throws
    func archiveTemporalArc(arcID: UUID) async throws
    func mergeTemporalArc(arcID: UUID) async throws -> TemporalArcDetailSnapshot?
    func fetchReflections(limit: Int?) throws -> [ReflectionSnapshot]
    func fetchReflectionSummaries(limit: Int?) throws -> [ReflectionSummarySnapshot]
    func fetchReflectionDetail(reflectionID: UUID) throws -> ReflectionDetailSnapshot?
    func saveReflection(reflectionID: UUID) async throws
    func dismissReflection(reflectionID: UUID) async throws
    func archiveReflection(reflectionID: UUID) async throws
    func fetchDebugDiagnostics(targetType: DebugAnalysisTarget, targetID: UUID?) throws -> DebugDiagnosticsSnapshot
    func rerunDebugPipeline(targetType: DebugAnalysisTarget, targetID: UUID?, mode: DebugRebuildMode) async throws
    func seedDebugFixtures(count: Int) async throws -> [DebugMemoryFixtureSnapshot]
    func clearDebugFixtures() throws
    func clearAllLocalData() throws
    func fetchUserSettingsPreference() throws -> UserSettingsPreference
    func saveUserSettingsPreference(_ preference: UserSettingsPreference) throws
    func fetchMemoryDetailPresentationPreference(recordID: UUID) throws -> MemoryDetailPresentationPreference?
    func saveMemoryDetailPresentationPreference(_ preference: MemoryDetailPresentationPreference) throws
    func clearMemoryDetailPresentationPreference(recordID: UUID) throws
    func fetchIntelligencePreferences() throws -> IntelligencePreferences
    func saveIntelligencePreferences(_ preferences: IntelligencePreferences) throws
    func fetchV6FeatureFlags() throws -> V6FeatureFlags
    func saveV6FeatureFlags(_ flags: V6FeatureFlags) throws
    func fetchSelfProfile() throws -> SelfProfile?
    func upsertSelfProfile(_ profile: SelfProfile) throws
    func ensureSelfProfile() throws -> SelfProfile
    func fetchEntityProfile(entityID: UUID) throws -> EntityProfile?
    func fetchEntityProfiles(kind: EntityKind?, limit: Int?) throws -> [EntityProfile]
    func upsertEntityProfile(_ profile: EntityProfile) throws
    func fetchPersonProfile(entityID: UUID) throws -> PersonProfile?
    func fetchPersonProfiles(limit: Int?) throws -> [PersonProfile]
    func upsertPersonProfile(_ profile: PersonProfile) throws
    func refreshPersonProfile(entityID: UUID, now: Date) throws -> PersonProfile?
    func applyPersonProfileMutation(_ mutation: PersonProfileMutation) throws -> PersonProfile
    func deletePersonProfilePortrait(entityID: UUID) throws -> PersonProfile
    func fetchAffectSnapshot(id: UUID) throws -> AffectSnapshot?
    func fetchAffectSnapshots(recordID: UUID?, limit: Int?) throws -> [AffectSnapshot]
    func upsertAffectSnapshot(_ snapshot: AffectSnapshot) throws
    func applyAffectCorrection(_ correction: AffectCorrection) throws -> AffectSnapshot
    func fetchPlaceProfile(id: UUID) throws -> PlaceProfile?
    func fetchPlaceProfiles(limit: Int?) throws -> [PlaceProfile]
    func upsertPlaceProfile(_ profile: PlaceProfile) throws
    func renamePlaceProfile(id: UUID, displayName: String, aliases: [String]) throws -> PlaceProfile
    func mergePlaceProfiles(primaryID: UUID, mergingIDs: [UUID], displayName: String?) throws -> PlaceProfile
    func splitPlaceProfile(id: UUID, movingArtifactIDs: [UUID], displayName: String) throws -> PlaceProfile
    func fetchPlaceProfileArtifacts(id: UUID) throws -> [Artifact]
    func mergePersonEntities(primaryID: UUID, mergingIDs: [UUID], displayName: String?) throws -> EntityProfile
    func splitPersonEntity(id: UUID, movingRecordIDs: [UUID], displayName: String, aliases: [String]) throws -> EntityProfile
    func fetchCorrectionEvents(kind: CorrectionEventKind?, limit: Int?) throws -> [CorrectionEvent]
    func upsertCorrectionEvent(_ event: CorrectionEvent) throws
    func reverseCorrectionEvent(_ id: UUID, reversedAt: Date) throws
    func fetchEntityTombstones(limit: Int?) throws -> [EntityTombstone]
    func fetchClarificationQuestions(status: ClarificationQuestionStatus?, limit: Int?) throws -> [ClarificationQuestion]
    func upsertClarificationQuestion(_ question: ClarificationQuestion) throws
    func answerClarificationQuestion(_ id: UUID, answer: ClarificationAnswer) throws
    func dismissClarificationQuestion(_ id: UUID) throws
    func fetchNotificationIntents(status: NotificationIntentStatus?, limit: Int?) throws -> [NotificationIntent]
    func upsertNotificationIntent(_ intent: NotificationIntent) throws
    func enqueueExternalCapture(_ request: ExternalCaptureRequest, receivedAt: Date) throws -> ExternalCaptureInboxItem
    func enqueueJournalingSuggestion(_ suggestion: JournalingSuggestionDraft, receivedAt: Date) throws -> ExternalCaptureInboxItem
    func fetchExternalCaptureInbox(status: ExternalCaptureInboxStatus?, limit: Int?) throws -> [ExternalCaptureInboxItem]
    func dismissExternalCaptureInboxItem(_ id: UUID) throws
    func createMemoryFromExternalCaptureInboxItem(_ id: UUID) async throws -> MemorySummary
    func fetchIntelligenceJobs(status: IntelligenceJobStatus?, limit: Int?) throws -> [IntelligenceJob]
    func upsertIntelligenceJob(_ job: IntelligenceJob) throws
    func fetchGraphDeltas(applied: Bool?, limit: Int?) throws -> [GraphDelta]
    func upsertGraphDelta(_ delta: GraphDelta) throws
    func markGraphDeltaApplied(_ id: UUID, appliedAt: Date) throws
    func rejectGraphDelta(_ id: UUID, note: String?) throws
    /// Applies a stored GraphDelta's operations to the entity graph (profile + node + optional merge).
    /// Idempotent: does nothing if `delta.appliedAt` is already set.
    func applyGraphDelta(_ id: UUID) throws
    func fetchQualityTuningPreference() throws -> QualityTuningPreference
    func saveQualityTuningPreference(_ preference: QualityTuningPreference) throws
    func runQualityTuningScenario(_ request: QualityTuningRunRequest) async throws -> QualityTuningRunReport
    func seedDebugFixture() async throws -> DebugMemoryFixtureSnapshot
    func fetchDebugFixtureSnapshot(recordID: UUID) throws -> DebugMemoryFixtureSnapshot?
}

protocol RecordAnalysisServing: Sendable {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot

    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot?
}

extension String {
    var trimmedOrNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var firstMeaningfulLine: String? {
        split(whereSeparator: { $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    func generatedMemoryTitle(maxLength: Int = 48) -> String? {
        guard let line = firstMeaningfulLine else { return nil }
        let sentenceTerminators = CharacterSet(charactersIn: ".!?。！？;；")
        let sentence = line.unicodeScalars.firstIndex(where: { sentenceTerminators.contains($0) })
            .map { String(line.unicodeScalars[..<$0]) }
            ?? line
        let normalized = sentence
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !normalized.isEmpty else { return nil }
        guard normalized.count > maxLength else { return normalized }
        return String(normalized.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    func ifEmpty(_ fallback: String) -> String {
        trimmedOrNil ?? fallback
    }
}

struct TimelineDayGroup: Identifiable, Hashable, Sendable {
    let date: Date
    let memories: [MemorySummary]
    var id: Date { date }
    var dayLabel: String { date.formatted(date: .abbreviated, time: .omitted) }
}

enum TimelineGranularity: String, CaseIterable, Identifiable, Sendable {
    case day, week, month
    var id: String { rawValue }
}

struct TimelineSnapshot: Hashable, Sendable {
    let granularity: TimelineGranularity
    let groups: [TimelineDayGroup]
    let totalCount: Int
}
