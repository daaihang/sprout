import Foundation

enum ExternalCaptureSourceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case appIntent
    case shortcut
    case shareSheet
    case journalingSuggestion
    case health
    case fitness
    case unknown

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

enum ExternalCaptureEvidenceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case link
    case location
    case locationGroup
    case song
    case podcast
    case genericMedia
    case photo
    case video
    case livePhoto
    case workout
    case workoutGroup
    case motionActivity
    case contact
    case reflection
    case stateOfMind
    case eventPoster
    case diagnostic

    var id: String { rawValue }
}

struct ExternalCaptureEvidenceItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var kind: ExternalCaptureEvidenceKind
    var title: String?
    var summary: String?
    var value: String?
    var startedAt: Date?
    var endedAt: Date?
    var metadata: [String: String]

    init(
        id: UUID = UUID(),
        kind: ExternalCaptureEvidenceKind,
        title: String? = nil,
        summary: String? = nil,
        value: String? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
        self.value = value
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.metadata = metadata
    }
}

enum ExternalCaptureAffectSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case userSelected
    case journalSuggestionStateOfMind
    case healthStateOfMind
    case fitnessContext
    case unknown

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

struct ExternalCaptureAffectEvidence: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var source: ExternalCaptureAffectSource
    var label: String?
    var labels: [String]
    var toneHints: [String]
    var associations: [String]
    var valence: Double?
    var valenceClassification: String?
    var kind: String?
    var rawInput: String?
    var confidence: Double?
    var userConfirmed: Bool
    var metadata: [String: String]

    init(
        id: UUID = UUID(),
        source: ExternalCaptureAffectSource,
        label: String? = nil,
        labels: [String] = [],
        toneHints: [String] = [],
        associations: [String] = [],
        valence: Double? = nil,
        valenceClassification: String? = nil,
        kind: String? = nil,
        rawInput: String? = nil,
        confidence: Double? = nil,
        userConfirmed: Bool = true,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.source = source
        self.label = label
        self.labels = labels
        self.toneHints = toneHints
        self.associations = associations
        self.valence = valence
        self.valenceClassification = valenceClassification
        self.kind = kind
        self.rawInput = rawInput
        self.confidence = confidence
        self.userConfirmed = userConfirmed
        self.metadata = metadata
    }
}
