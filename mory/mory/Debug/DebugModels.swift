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

// MARK: - Quality Tuning Lab

enum QualityTuningScenarioID: String, CaseIterable, Identifiable, Sendable {
    case ordinaryShortText
    case terseNeutralText
    case longReflectiveText
    case highEmotionShortText
    case strongEmotionText
    case photoOCRNoise
    case photoRealSubject
    case linkCapture
    case speechTranscript
    case multiArtifactContext
    case ambientContextOnly
    case twoRelatedEvents
    case weakRelatedEvents
    case denseUnrelatedHistory
    case recurringCareerHistory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ordinaryShortText: "Ordinary short text"
        case .terseNeutralText: "Terse neutral text"
        case .longReflectiveText: "Long reflective text"
        case .highEmotionShortText: "High emotion short text"
        case .strongEmotionText: "Strong emotion text"
        case .photoOCRNoise: "Photo / OCR noise"
        case .photoRealSubject: "Photo with real subject"
        case .linkCapture: "Link capture"
        case .speechTranscript: "Speech transcript"
        case .multiArtifactContext: "Multi artifact context"
        case .ambientContextOnly: "Ambient context only"
        case .twoRelatedEvents: "Two related events"
        case .weakRelatedEvents: "Weak related events"
        case .denseUnrelatedHistory: "Dense unrelated history"
        case .recurringCareerHistory: "Recurring career history"
        }
    }
}

enum QualityTuningExpectation: String, Codable, Sendable {
    case noArcNoReflection
    case arcExpected
    case reflectionAllowed
    case inspectOnly
}

struct QualityTuningScenario: Identifiable, Sendable {
    let id: QualityTuningScenarioID
    var title: String
    var body: String
    var mood: String?
    var context: String
    var captureSource: CaptureSource
    var artifacts: [CaptureArtifactDraft]
    var expectation: QualityTuningExpectation

    static func preset(_ id: QualityTuningScenarioID) -> QualityTuningScenario {
        switch id {
        case .ordinaryShortText:
            return .init(
                id: id,
                title: id.title,
                body: "Saw a receipt on the desk and took a quick note.",
                mood: nil,
                context: "quality tuning lab: ordinary short text",
                captureSource: .composer,
                artifacts: [.text(title: id.title, body: "Saw a receipt on the desk and took a quick note.")],
                expectation: .noArcNoReflection
            )
        case .terseNeutralText:
            let body = "Coffee. Inbox. Done."
            return .init(
                id: id,
                title: id.title,
                body: body,
                mood: nil,
                context: "quality tuning lab: terse neutral text",
                captureSource: .composer,
                artifacts: [.text(title: id.title, body: body)],
                expectation: .noArcNoReflection
            )
        case .longReflectiveText:
            let body = "I spent the morning comparing the two versions of the launch plan. The smaller version feels less impressive, but it gives the team a real chance to finish the work with care. I keep noticing the same pattern: when I protect scope early, I feel calmer and make better decisions later."
            return .init(
                id: id,
                title: id.title,
                body: body,
                mood: "reflective",
                context: "quality tuning lab: long reflective text",
                captureSource: .composer,
                artifacts: [.text(title: id.title, body: body)],
                expectation: .reflectionAllowed
            )
        case .highEmotionShortText:
            let body = "I panicked after the meeting."
            return .init(
                id: id,
                title: id.title,
                body: body,
                mood: "anxious",
                context: "quality tuning lab: high emotion short text",
                captureSource: .composer,
                artifacts: [.text(title: id.title, body: body)],
                expectation: .noArcNoReflection
            )
        case .strongEmotionText:
            let body = "The conversation with Linh about leaving my current role felt unusually clear. I noticed relief, fear, and a concrete next step: write the transition plan before Friday."
            return .init(id: id, title: id.title, body: body, mood: "intense", context: "quality tuning lab: strong emotion text", captureSource: .composer, artifacts: [.text(title: id.title, body: body)], expectation: .reflectionAllowed)
        case .photoOCRNoise:
            return .init(
                id: id,
                title: id.title,
                body: "Photo import with weak OCR.",
                mood: nil,
                context: "quality tuning lab: photo OCR noise",
                captureSource: .photo,
                artifacts: [.photo(title: "Receipt photo", summary: "OCR ORC theme photo image artifact", filename: "debug_ocr_noise.jpg", imageData: nil, thumbnailData: nil, ocrText: "OCR ORC theme photo image artifact")],
                expectation: .noArcNoReflection
            )
        case .photoRealSubject:
            let body = "Photo from the pottery class with Mira; the bowl cracked, but we decided to try the same glaze again next week."
            return .init(
                id: id,
                title: id.title,
                body: body,
                mood: "warm",
                context: "quality tuning lab: photo real subject",
                captureSource: .photo,
                artifacts: [
                    .photo(title: "Pottery class photo", summary: "Mira at pottery class with a cracked bowl and green glaze", filename: "pottery_class.jpg", imageData: nil, thumbnailData: nil, ocrText: "")
                ],
                expectation: .inspectOnly
            )
        case .linkCapture:
            let body = "Saved an article about decision fatigue for later."
            return .init(id: id, title: id.title, body: body, mood: "curious", context: "quality tuning lab: link capture", captureSource: .composer, artifacts: [.text(title: id.title, body: body), .link(title: "Decision fatigue article", url: "https://example.com/decision-fatigue", note: body, summary: "Article about decision fatigue and planning habits.")], expectation: .inspectOnly)
        case .speechTranscript:
            let body = "Voice note transcript: I keep returning to the same question about how to protect mornings for writing before meetings start."
            return .init(id: id, title: id.title, body: body, mood: "focused", context: "quality tuning lab: speech transcript", captureSource: .audio, artifacts: [.audio(title: "Voice note", summary: "Speech transcription", filename: "debug_voice.m4a", audioData: nil, transcriptionText: body)], expectation: .reflectionAllowed)
        case .multiArtifactContext:
            let body = "Planning walk with Linh around the river, thinking about the launch checklist."
            return .init(
                id: id,
                title: id.title,
                body: body,
                mood: "reflective",
                context: "quality tuning lab: multi artifact context",
                captureSource: .composer,
                artifacts: [
                    .text(title: id.title, body: body),
                    .location(title: "River path", summary: "River path near home", latitude: 37.87, longitude: -122.27),
                    .weather(condition: "Cloudy", temperatureCelsius: 18, humidity: 0.62, windSpeedKmh: 7, uvIndex: 2),
                    .music(trackName: "Nightcall", artistName: "Kavinsky", albumName: "OutRun", durationSeconds: 258, artworkURL: nil)
                ],
                expectation: .inspectOnly
            )
        case .ambientContextOnly:
            return .init(
                id: id,
                title: id.title,
                body: "Auto context capture with no user-written memory.",
                mood: nil,
                context: "quality tuning lab: ambient context only",
                captureSource: .composer,
                artifacts: [
                    .location(title: "Downtown station", summary: "Downtown station", latitude: 37.78, longitude: -122.41),
                    .weather(condition: "Rain", temperatureCelsius: 12, humidity: 0.88, windSpeedKmh: 13, uvIndex: 1),
                    .music(trackName: "Intro", artistName: "The xx", albumName: "xx", durationSeconds: 127, artworkURL: nil)
                ],
                expectation: .noArcNoReflection
            )
        case .twoRelatedEvents:
            let body = "Second planning walk with Linh clarified the same launch checklist and the decision to reduce scope."
            return .init(id: id, title: id.title, body: body, mood: "reflective", context: "quality tuning lab: two related events", captureSource: .composer, artifacts: [.text(title: id.title, body: body)], expectation: .arcExpected)
        case .weakRelatedEvents:
            let body = "A calendar note, a grocery reminder, and a random photo were captured near the same afternoon."
            return .init(id: id, title: id.title, body: body, mood: nil, context: "quality tuning lab: weak related events", captureSource: .composer, artifacts: [.text(title: id.title, body: body)], expectation: .noArcNoReflection)
        case .denseUnrelatedHistory:
            let body = "Three unrelated notes landed close together: a dentist reminder, a grocery list, and a screenshot of a receipt."
            return .init(id: id, title: id.title, body: body, mood: nil, context: "quality tuning lab: dense unrelated history", captureSource: .composer, artifacts: [.text(title: id.title, body: body)], expectation: .noArcNoReflection)
        case .recurringCareerHistory:
            let body = "Third note about the same career transition: I told Linh the smaller launch scope is the version I can actually stand behind."
            return .init(id: id, title: id.title, body: body, mood: "resolved", context: "quality tuning lab: recurring career history", captureSource: .composer, artifacts: [.text(title: id.title, body: body)], expectation: .arcExpected)
        }
    }
}

struct QualityTuningRunRequest: Sendable {
    var scenario: QualityTuningScenario
    var promptProfile: QualityTuningPromptProfile
    var thresholds: QualityTuningThresholds
}

struct QualityTuningGateSnapshot: Identifiable, Sendable {
    let id = UUID()
    var title: String
    var passed: Bool
    var detail: String
}

struct QualityTuningRunReport: Identifiable, Sendable {
    let id = UUID()
    var scenarioTitle: String
    var promptProfile: QualityTuningPromptProfile
    var thresholdsSummary: String
    var recordIDs: [UUID]
    var expectation: QualityTuningExpectation
    var expectationPassed: Bool
    var requestBody: String
    var rawResponseBody: String
    var filteredSummary: String
    var storedSummary: String
    var gates: [QualityTuningGateSnapshot]
    var createdAt: Date

    var exportText: String {
        var lines: [String] = []
        lines.append("=== Mory Quality Tuning Report ===")
        lines.append("Scenario: \(scenarioTitle)")
        lines.append("Profile: \(promptProfile.rawValue)")
        lines.append("Created at: \(createdAt.formatted(.iso8601))")
        lines.append("Thresholds: \(thresholdsSummary)")
        lines.append("Record IDs: \(recordIDs.map(\.uuidString).joined(separator: ", "))")
        lines.append("Expectation: \(expectation.rawValue) -> \(expectationPassed ? "PASS" : "FAIL")")
        lines.append("")
        lines.append("--- Gates ---")
        lines.append(contentsOf: gates.map { "\($0.passed ? "PASS" : "FAIL") \($0.title): \($0.detail)" })
        lines.append("")
        lines.append("--- Filtered ---")
        lines.append(filteredSummary)
        lines.append("")
        lines.append("--- Stored ---")
        lines.append(storedSummary)
        lines.append("")
        lines.append("--- Request ---")
        lines.append(requestBody)
        lines.append("")
        lines.append("--- Raw Response ---")
        lines.append(rawResponseBody)
        return lines.joined(separator: "\n")
    }
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
