import Foundation

struct ContentQualityGateResult: Hashable, Sendable {
    var passed: Bool
    var reason: String
    var metric: String?
}

struct QualityTuningThresholds: Codable, Hashable, Sendable {
    var entityMinimumConfidence: Double
    var themeDecisionMinimumConfidence: Double
    var arcMinimumRecordCount: Int
    var arcMinimumClusterStrength: Double
    var arcMinimumIntensityScore: Double
    var arcMinimumAverageSalience: Double
    var reflectionMinimumRecordSalience: Double
    var reflectionMinimumEvidenceCharacters: Int
    var reflectionMinimumResultConfidence: Double
    var reflectionMinimumBodyCharacters: Int

    static let defaults = QualityTuningThresholds(
        entityMinimumConfidence: 0.55,
        themeDecisionMinimumConfidence: 0.65,
        arcMinimumRecordCount: 2,
        arcMinimumClusterStrength: 0.55,
        arcMinimumIntensityScore: 4.0,
        arcMinimumAverageSalience: 0.55,
        reflectionMinimumRecordSalience: 0.75,
        reflectionMinimumEvidenceCharacters: 100,
        reflectionMinimumResultConfidence: 0.70,
        reflectionMinimumBodyCharacters: 80
    )

    var summary: String {
        [
            "entity >= \(entityMinimumConfidence)",
            "theme/decision >= \(themeDecisionMinimumConfidence)",
            "arc records >= \(arcMinimumRecordCount)",
            "arc cluster >= \(arcMinimumClusterStrength)",
            "arc avg salience >= \(arcMinimumAverageSalience)",
            "reflection salience >= \(reflectionMinimumRecordSalience)",
            "reflection evidence >= \(reflectionMinimumEvidenceCharacters)",
            "reflection confidence >= \(reflectionMinimumResultConfidence)"
        ].joined(separator: " | ")
    }
}

enum QualityTuningPromptProfile: String, Codable, CaseIterable, Identifiable, Sendable {
    case strict
    case balanced
    case experimental

    var id: String { rawValue }
}

enum QualityTuningRuntime {
    private static let enabledKey = "mory.debug.qualityTuning.enabled"
    private static let thresholdsKey = "mory.debug.qualityTuning.thresholds"
    private static let promptProfileKey = "mory.debug.qualityTuning.promptProfile"
    private static let lock = NSLock()
    private nonisolated(unsafe) static var recordScope: Set<UUID>?

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var thresholds: QualityTuningThresholds {
        get {
            guard
                let data = UserDefaults.standard.data(forKey: thresholdsKey),
                let decoded = try? JSONDecoder().decode(QualityTuningThresholds.self, from: data)
            else {
                return .defaults
            }
            return decoded
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: thresholdsKey)
        }
    }

    static var promptProfile: QualityTuningPromptProfile {
        get {
            guard
                let rawValue = UserDefaults.standard.string(forKey: promptProfileKey),
                let profile = QualityTuningPromptProfile(rawValue: rawValue)
            else {
                return .balanced
            }
            return profile
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: promptProfileKey)
        }
    }

    static var isUsingDefaultThresholds: Bool {
        thresholds == .defaults
    }

    static var isActive: Bool {
        isEnabled && activeRecordScope != nil
    }

    static var activeThresholds: QualityTuningThresholds {
        isActive ? thresholds : .defaults
    }

    static var activeRecordScope: Set<UUID>? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return recordScope
        }
        set {
            lock.lock()
            recordScope = newValue
            lock.unlock()
        }
    }
}

struct EntityQualityPolicy: Sendable {
    private let configuredThresholds: QualityTuningThresholds?
    private var thresholds: QualityTuningThresholds {
        configuredThresholds ?? QualityTuningRuntime.activeThresholds
    }
    private let bannedExactNames: Set<String> = [
        "theme", "themes", "ocr", "orc", "photo", "photos", "image", "images",
        "caption", "artifact", "artifacts", "text", "unknown", "untitled", "none", "n/a",
        "quality tuning", "quality tuning lab", "tuning lab", "debug", "fixture", "scenario",
        "receipt", "receipts", "screenshot", "screenshots", "bookmark", "bookmarks", "link", "links"
    ]
    private let bannedShortTokens: Set<String> = [
        "ocr", "orc", "photo", "image", "caption", "artifact", "debug", "fixture", "scenario", "tuning",
        "receipt", "screenshot", "bookmark", "link"
    ]

    init(thresholds: QualityTuningThresholds? = nil) {
        self.configuredThresholds = thresholds
    }

    func filter(_ references: [EntityReference]) -> [EntityReference] {
        var seen = Set<String>()
        return references.compactMap { reference in
            let result = evaluate(reference)
            guard result.passed else { return nil }
            let key = "\(reference.kind.rawValue):\(normalizedName(reference.name))"
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return reference
        }
    }

    func evaluate(_ reference: EntityReference) -> ContentQualityGateResult {
        let name = reference.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizedName(name)
        guard !normalized.isEmpty else {
            return .init(passed: false, reason: "empty entity name", metric: nil)
        }
        guard normalized != reference.kind.rawValue else {
            return .init(passed: false, reason: "entity name equals kind", metric: normalized)
        }
        guard !bannedExactNames.contains(normalized) else {
            return .init(passed: false, reason: "technical or generic label", metric: normalized)
        }
        let tokens = normalized.split(separator: " ").map(String.init)
        if tokens.count <= 2, tokens.contains(where: { bannedShortTokens.contains($0) }) {
            return .init(passed: false, reason: "artifact processing label", metric: normalized)
        }
        guard name.count <= 48 else {
            return .init(passed: false, reason: "entity name too long", metric: "\(name.count) chars")
        }
        let minimum = minimumConfidence(for: reference.kind)
        guard let confidence = reference.confidence else {
            return .init(passed: false, reason: "missing confidence", metric: "required >= \(minimum)")
        }
        guard confidence >= minimum else {
            return .init(passed: false, reason: "confidence below threshold", metric: "\(confidence) < \(minimum)")
        }
        if reference.kind == .theme || reference.kind == .decision {
            guard tokens.count >= 1, normalized.count >= 4 else {
                return .init(passed: false, reason: "semantic label too short", metric: normalized)
            }
        }
        return .init(passed: true, reason: "accepted", metric: "confidence \(confidence)")
    }

    func usefulThemeLabel(_ value: String) -> Bool {
        let normalized = normalizedName(value)
        guard !normalized.isEmpty else { return false }
        guard normalized.count >= 4 else { return false }
        guard !bannedExactNames.contains(normalized) else { return false }
        let tokens = normalized.split(separator: " ").map(String.init)
        if tokens.count <= 2, tokens.contains(where: { bannedShortTokens.contains($0) }) {
            return false
        }
        return true
    }

    private func minimumConfidence(for kind: EntityKind) -> Double {
        switch kind {
        case .theme, .decision:
            return thresholds.themeDecisionMinimumConfidence
        case .person, .place, .activity, .object:
            return thresholds.entityMinimumConfidence
        }
    }

    private func normalizedName(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ArcQualityPolicy: Sendable {
    private let configuredThresholds: QualityTuningThresholds?
    private var thresholds: QualityTuningThresholds {
        configuredThresholds ?? QualityTuningRuntime.activeThresholds
    }

    init(thresholds: QualityTuningThresholds? = nil) {
        self.configuredThresholds = thresholds
    }

    func evaluate(_ candidate: TemporalArcCandidate) -> ContentQualityGateResult {
        let uniqueRecordCount = Set(candidate.recordIDs).count
        guard uniqueRecordCount >= thresholds.arcMinimumRecordCount else {
            return .init(passed: false, reason: "needs more linked memories", metric: "\(uniqueRecordCount) < \(thresholds.arcMinimumRecordCount)")
        }
        let requiredAverageSalience = averageSalienceFloor(for: candidate, uniqueRecordCount: uniqueRecordCount)
        guard candidate.averageSalience >= requiredAverageSalience else {
            return .init(passed: false, reason: "average salience below threshold", metric: "\(candidate.averageSalience) < \(requiredAverageSalience)")
        }
        let requiredClusterStrength = relaxedClusterStrengthFloor(for: candidate, uniqueRecordCount: uniqueRecordCount)
        guard candidate.clusterStrength >= requiredClusterStrength else {
            return .init(passed: false, reason: "cluster strength below threshold", metric: "\(candidate.clusterStrength) < \(requiredClusterStrength)")
        }
        guard candidate.intensityScore >= thresholds.arcMinimumIntensityScore else {
            return .init(passed: false, reason: "intensity below threshold", metric: "\(candidate.intensityScore) < \(thresholds.arcMinimumIntensityScore)")
        }
        guard !candidate.themeLabels.isEmpty || !candidate.entityNames.isEmpty else {
            return .init(passed: false, reason: "missing shared theme or entity anchor", metric: nil)
        }
        return .init(passed: true, reason: "accepted", metric: "records \(uniqueRecordCount), cluster \(candidate.clusterStrength)")
    }

    private func relaxedClusterStrengthFloor(for candidate: TemporalArcCandidate, uniqueRecordCount: Int) -> Double {
        guard uniqueRecordCount >= 3, candidate.averageSalience >= 0.45 else {
            return thresholds.arcMinimumClusterStrength
        }
        return min(thresholds.arcMinimumClusterStrength, 0.4)
    }

    private func averageSalienceFloor(for candidate: TemporalArcCandidate, uniqueRecordCount: Int) -> Double {
        guard uniqueRecordCount >= 3,
              candidate.clusterStrength >= 0.42,
              (!candidate.themeLabels.isEmpty || !candidate.entityNames.isEmpty)
        else {
            return thresholds.arcMinimumAverageSalience
        }
        return min(thresholds.arcMinimumAverageSalience, 0.45)
    }
}

struct ReflectionQualityPolicy: Sendable {
    private let configuredThresholds: QualityTuningThresholds?
    private var thresholds: QualityTuningThresholds {
        configuredThresholds ?? QualityTuningRuntime.activeThresholds
    }

    init(thresholds: QualityTuningThresholds? = nil) {
        self.configuredThresholds = thresholds
    }

    func shouldRequestRecordReflection(record: RecordShell, artifacts: [Artifact], analysis: RecordAnalysisSnapshot) -> ContentQualityGateResult {
        let salience = analysis.salienceScore ?? 0
        let evidence = evidenceText(record: record, artifacts: artifacts)
        let hintLength = analysis.reflectionHint?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0
        guard salience >= thresholds.reflectionMinimumRecordSalience else {
            if isEligibleVoiceTranscript(record: record, artifacts: artifacts, evidence: evidence, analysis: analysis) {
                return .init(passed: true, reason: "voice transcript recurring constraint", metric: "salience \(salience)")
            }
            if isExplicitDecisionReflectionCandidate(evidence: evidence, analysis: analysis) {
                return .init(passed: true, reason: "explicit decision reflection candidate", metric: "salience \(salience)")
            }
            return .init(passed: false, reason: "salience below threshold", metric: "\(salience) < \(thresholds.reflectionMinimumRecordSalience)")
        }
        guard evidence.count >= thresholds.reflectionMinimumEvidenceCharacters else {
            return .init(passed: false, reason: "not enough evidence text", metric: "\(evidence.count) chars")
        }
        guard hintLength >= 20 else {
            return .init(passed: false, reason: "weak reflection hint", metric: nil)
        }
        return .init(passed: true, reason: "request allowed", metric: "salience \(salience)")
    }

    func shouldStoreRecordReflection(_ result: ReflectionServiceResult) -> ContentQualityGateResult {
        guard result.confidence >= thresholds.reflectionMinimumResultConfidence else {
            return .init(passed: false, reason: "reflection confidence below threshold", metric: "\(result.confidence) < \(thresholds.reflectionMinimumResultConfidence)")
        }
        guard result.body.trimmingCharacters(in: .whitespacesAndNewlines).count >= thresholds.reflectionMinimumBodyCharacters else {
            return .init(passed: false, reason: "reflection body too short", metric: "\(result.body.count) chars")
        }
        guard !result.evidenceSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .init(passed: false, reason: "missing evidence summary", metric: nil)
        }
        return .init(passed: true, reason: "accepted", metric: "confidence \(result.confidence)")
    }

    func shouldStoreRecordReflection(
        _ result: ReflectionServiceResult,
        record: RecordShell,
        artifacts: [Artifact],
        analysis: RecordAnalysisSnapshot
    ) -> ContentQualityGateResult {
        let evidence = evidenceText(record: record, artifacts: artifacts)
        let voiceTranscriptEligible = isEligibleVoiceTranscript(
            record: record,
            artifacts: artifacts,
            evidence: evidence,
            analysis: analysis
        )
        let explicitDecisionEligible = isExplicitDecisionReflectionCandidate(evidence: evidence, analysis: analysis)

        if result.confidence < thresholds.reflectionMinimumResultConfidence {
            let relaxedMinimum = voiceTranscriptEligible ? 0.35 : (explicitDecisionEligible ? 0.60 : thresholds.reflectionMinimumResultConfidence)
            guard result.confidence >= relaxedMinimum else {
                return .init(passed: false, reason: "reflection confidence below threshold", metric: "\(result.confidence) < \(thresholds.reflectionMinimumResultConfidence)")
            }
        }
        guard result.body.trimmingCharacters(in: .whitespacesAndNewlines).count >= thresholds.reflectionMinimumBodyCharacters else {
            return .init(passed: false, reason: "reflection body too short", metric: "\(result.body.count) chars")
        }
        guard !result.evidenceSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .init(passed: false, reason: "missing evidence summary", metric: nil)
        }

        if result.confidence < thresholds.reflectionMinimumResultConfidence {
            let reason = voiceTranscriptEligible ? "accepted voice transcript reflection" : "accepted explicit decision reflection"
            return .init(passed: true, reason: reason, metric: "confidence \(result.confidence)")
        }
        return .init(passed: true, reason: "accepted", metric: "confidence \(result.confidence)")
    }

    private func evidenceText(record: RecordShell, artifacts: [Artifact]) -> String {
        ([record.rawText] + artifacts.flatMap { [$0.title, $0.summary, $0.textContent] })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isEligibleVoiceTranscript(record: RecordShell, artifacts: [Artifact], evidence: String, analysis: RecordAnalysisSnapshot) -> Bool {
        let isAudio = record.captureSource == .audio || record.captureSource == .voice || artifacts.contains { $0.kind == .audio }
        guard isAudio else { return false }
        guard evidence.count >= thresholds.reflectionMinimumEvidenceCharacters else { return false }

        let normalizedEvidence = evidence.lowercased()
        let normalizedThemes = analysis.themes.joined(separator: " ").lowercased()
        let recurringSignal = [
            "keep returning",
            "same question",
            "recurring",
            "again",
            "protect",
            "boundary",
            "boundaries"
        ].contains { normalizedEvidence.contains($0) || normalizedThemes.contains($0) }
        let creativeWorkSignal = [
            "writing",
            "creative",
            "mornings",
            "morning",
            "focus"
        ].contains { normalizedEvidence.contains($0) || normalizedThemes.contains($0) }
        guard recurringSignal && creativeWorkSignal else { return false }

        return (analysis.salienceScore ?? 0) >= 0.3
    }

    private func isExplicitDecisionReflectionCandidate(evidence: String, analysis: RecordAnalysisSnapshot) -> Bool {
        guard evidence.count >= thresholds.reflectionMinimumEvidenceCharacters else { return false }
        guard (analysis.salienceScore ?? 0) >= 0.70 else { return false }
        let hintLength = analysis.reflectionHint?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0
        guard hintLength >= 20 else { return false }

        let corpus = [
            evidence,
            analysis.summary,
            analysis.themes.joined(separator: " "),
            analysis.retrievalTerms.joined(separator: " ")
        ].joined(separator: " ").lowercased()

        let decisionSignals = [
            "decision", "decide", "decided", "chose", "choose", "scope", "protect",
            "launch", "transition", "onboarding", "plan", "pattern",
            "决定", "选择", "范围", "保护", "复盘", "砍掉", "保留"
        ]
        let reflectionSignals = [
            "relief", "relieved", "calmer", "clear", "clarity", "noticing", "pattern",
            "better decisions", "future", "apply", "松了一口气", "清楚", "复盘", "模式"
        ]

        return decisionSignals.contains { corpus.contains($0) }
            && reflectionSignals.contains { corpus.contains($0) }
    }
}
