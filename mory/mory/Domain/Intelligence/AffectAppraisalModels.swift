import Foundation

nonisolated enum AppraisalAgency: String, Codable, CaseIterable, Identifiable, Sendable {
    case selfAgency
    case other
    case situation
    case unknown

    var id: String { rawValue }
}

nonisolated enum GoalAlignment: String, Codable, CaseIterable, Identifiable, Sendable {
    case blocked
    case neutral
    case supported

    var id: String { rawValue }
}

nonisolated enum AffectEvidenceSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case userSelected
    case userFreeform
    case aiInferredText
    case aiInferredImage
    case voiceProsody
    case journalSuggestionStateOfMind
    case healthOrWorkoutContext
    case userCorrected

    var id: String { rawValue }
}

nonisolated struct AffectAppraisal: Codable, Hashable, Sendable {
    var agency: AppraisalAgency?
    var certainty: Double?
    var control: Double?
    var goalAlignment: GoalAlignment?
    var socialSafety: Double?
    var novelty: Double?
    var copingPotential: Double?
    var targetEntityIDs: [UUID]
    var targetThemeIDs: [UUID]

    init(
        agency: AppraisalAgency? = nil,
        certainty: Double? = nil,
        control: Double? = nil,
        goalAlignment: GoalAlignment? = nil,
        socialSafety: Double? = nil,
        novelty: Double? = nil,
        copingPotential: Double? = nil,
        targetEntityIDs: [UUID] = [],
        targetThemeIDs: [UUID] = []
    ) {
        self.agency = agency
        self.certainty = certainty.map(Self.clamped01)
        self.control = control.map(Self.clamped01)
        self.goalAlignment = goalAlignment
        self.socialSafety = socialSafety.map(Self.clamped01)
        self.novelty = novelty.map(Self.clamped01)
        self.copingPotential = copingPotential.map(Self.clamped01)
        self.targetEntityIDs = targetEntityIDs
        self.targetThemeIDs = targetThemeIDs
    }

    private static func clamped01(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

nonisolated struct AffectEvidence: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var source: AffectEvidenceSource
    var summary: String
    var confidence: Double?
    var metadata: [String: String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        source: AffectEvidenceSource,
        summary: String,
        confidence: Double? = nil,
        metadata: [String: String] = [:],
        createdAt: Date = .now
    ) {
        self.id = id
        self.source = source
        self.summary = summary
        self.confidence = confidence.map { min(1, max(0, $0)) }
        self.metadata = metadata
        self.createdAt = createdAt
    }
}
