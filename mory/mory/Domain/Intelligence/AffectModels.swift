import Foundation

nonisolated enum AffectLabel: String, Codable, CaseIterable, Identifiable, Sendable {
    case excited
    case amazed
    case inspired
    case proud
    case curious
    case brave
    case confident
    case content
    case happy
    case hopeful
    case joyful
    case passionate
    case peaceful
    case satisfied
    case calm
    case grateful
    case relieved
    case warm
    case angry
    case annoyed
    case ashamed
    case disappointed
    case discouraged
    case disgusted
    case embarrassed
    case frustrated
    case guilty
    case hopeless
    case irritated
    case jealous
    case anxious
    case tense
    case overwhelmed
    case scared
    case surprised
    case worried
    case drained
    case indifferent
    case tired
    case sad
    case lonely
    case numb
    case amused
    case mockFrustrated
    case stressed
    case playful
    case uncertain

    var id: String { rawValue }
}

nonisolated enum ToneHint: String, Codable, CaseIterable, Identifiable, Sendable {
    case joking
    case playful
    case sarcastic
    case venting
    case serious
    case tender
    case exhausted
    case uncertain

    var id: String { rawValue }
}

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

nonisolated struct AffectSnapshot: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var recordID: UUID
    var valence: Double?
    var arousal: Double?
    var dominance: Double?
    var intensity: Double?
    var labels: [AffectLabel]
    var toneHints: [ToneHint]
    var appraisal: AffectAppraisal?
    var sources: [AffectEvidenceSource]
    var confidence: Double?
    var evidence: [AffectEvidence]
    var userConfirmed: Bool
    var needsUserCheck: Bool
    var rawInput: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        recordID: UUID,
        valence: Double? = nil,
        arousal: Double? = nil,
        dominance: Double? = nil,
        intensity: Double? = nil,
        labels: [AffectLabel] = [],
        toneHints: [ToneHint] = [],
        appraisal: AffectAppraisal? = nil,
        sources: [AffectEvidenceSource] = [],
        confidence: Double? = nil,
        evidence: [AffectEvidence] = [],
        userConfirmed: Bool = false,
        needsUserCheck: Bool = false,
        rawInput: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.recordID = recordID
        self.valence = valence.map(Self.clampedValence)
        self.arousal = arousal.map(Self.clamped01)
        self.dominance = dominance.map(Self.clamped01)
        self.intensity = intensity.map(Self.clamped01)
        self.labels = Array(Self.orderedUnique(labels))
        self.toneHints = Array(Self.orderedUnique(toneHints))
        self.appraisal = appraisal
        self.sources = Array(Self.orderedUnique(sources))
        self.confidence = confidence.map(Self.clamped01)
        self.evidence = evidence
        self.userConfirmed = userConfirmed
        self.needsUserCheck = needsUserCheck
        self.rawInput = rawInput
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var primaryLabel: AffectLabel? {
        labels.first
    }

    var primaryMoodText: String {
        primaryLabel?.rawValue ?? rawInput ?? "unknown"
    }

    private static func clampedValence(_ value: Double) -> Double {
        min(1, max(-1, value))
    }

    private static func clamped01(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func orderedUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        var result: [T] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}

nonisolated struct AffectSnapshotDraft: Codable, Hashable, Sendable {
    var valence: Double?
    var arousal: Double?
    var dominance: Double?
    var intensity: Double?
    var labels: [AffectLabel]
    var toneHints: [ToneHint]
    var appraisal: AffectAppraisal?
    var sources: [AffectEvidenceSource]
    var confidence: Double?
    var evidenceSummary: String?
    var userConfirmed: Bool
    var rawInput: String?

    init(
        valence: Double? = nil,
        arousal: Double? = nil,
        dominance: Double? = nil,
        intensity: Double? = nil,
        labels: [AffectLabel] = [],
        toneHints: [ToneHint] = [],
        appraisal: AffectAppraisal? = nil,
        sources: [AffectEvidenceSource] = [],
        confidence: Double? = nil,
        evidenceSummary: String? = nil,
        userConfirmed: Bool = false,
        rawInput: String? = nil
    ) {
        self.valence = valence
        self.arousal = arousal
        self.dominance = dominance
        self.intensity = intensity
        self.labels = labels
        self.toneHints = toneHints
        self.appraisal = appraisal
        self.sources = sources
        self.confidence = confidence
        self.evidenceSummary = evidenceSummary
        self.userConfirmed = userConfirmed
        self.rawInput = rawInput
    }
}

nonisolated struct AffectCorrection: Codable, Hashable, Sendable {
    var snapshotID: UUID?
    var recordID: UUID
    var valence: Double?
    var arousal: Double?
    var dominance: Double?
    var intensity: Double?
    var labels: [AffectLabel]
    var toneHints: [ToneHint]
    var appraisal: AffectAppraisal?
    var note: String?
    var createdAt: Date

    init(
        snapshotID: UUID? = nil,
        recordID: UUID,
        valence: Double? = nil,
        arousal: Double? = nil,
        dominance: Double? = nil,
        intensity: Double? = nil,
        labels: [AffectLabel] = [],
        toneHints: [ToneHint] = [],
        appraisal: AffectAppraisal? = nil,
        note: String? = nil,
        createdAt: Date = .now
    ) {
        self.snapshotID = snapshotID
        self.recordID = recordID
        self.valence = valence
        self.arousal = arousal
        self.dominance = dominance
        self.intensity = intensity
        self.labels = labels
        self.toneHints = toneHints
        self.appraisal = appraisal
        self.note = note
        self.createdAt = createdAt
    }
}

nonisolated struct AffectSnapshotMapper: Sendable {
    func snapshot(
        recordID: UUID,
        rawMood: String?,
        userIntensity: Int? = nil,
        source: AffectEvidenceSource = .userFreeform,
        now: Date = .now
    ) -> AffectSnapshot? {
        guard let draft = draft(rawMood: rawMood, userIntensity: userIntensity, source: source) else {
            return nil
        }
        return snapshot(recordID: recordID, draft: draft, now: now)
    }

    func snapshot(recordID: UUID, draft: AffectSnapshotDraft, now: Date = .now) -> AffectSnapshot {
        let evidenceSummary = draft.evidenceSummary
            ?? draft.rawInput
            ?? draft.labels.map(\.rawValue).joined(separator: ", ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let evidence = evidenceSummary.isEmpty
            ? []
            : draft.sources.map { source in
                AffectEvidence(
                    source: source,
                    summary: evidenceSummary,
                    confidence: draft.confidence,
                    metadata: evidenceMetadata(from: draft),
                    createdAt: now
                )
            }
        return AffectSnapshot(
            recordID: recordID,
            valence: draft.valence,
            arousal: draft.arousal,
            dominance: draft.dominance,
            intensity: draft.intensity,
            labels: draft.labels,
            toneHints: draft.toneHints,
            appraisal: draft.appraisal,
            sources: draft.sources,
            confidence: draft.confidence,
            evidence: evidence,
            userConfirmed: draft.userConfirmed,
            needsUserCheck: needsUserCheck(confidence: draft.confidence, toneHints: draft.toneHints),
            rawInput: draft.rawInput,
            createdAt: now,
            updatedAt: now
        )
    }

    func draft(
        rawMood: String?,
        userIntensity: Int? = nil,
        source: AffectEvidenceSource = .userFreeform
    ) -> AffectSnapshotDraft? {
        guard let rawMood = rawMood?.trimmingCharacters(in: .whitespacesAndNewlines), !rawMood.isEmpty else {
            return nil
        }

        let normalized = rawMood.lowercased()
        let labels = labels(for: normalized)
        let toneHints = toneHints(for: normalized)
        let vector = vector(labels: labels, toneHints: toneHints, normalizedText: normalized)
        let confidence = confidence(labels: labels, toneHints: toneHints, normalizedText: normalized)
        let appraisal = appraisal(labels: labels, toneHints: toneHints, normalizedText: normalized)
        let intensity = userIntensity.map { min(1, max(0, Double($0) / 5.0)) } ?? vector.intensity
        let resolvedSource: AffectEvidenceSource = isKnownChip(normalized) ? .userSelected : source

        return AffectSnapshotDraft(
            valence: vector.valence,
            arousal: vector.arousal,
            dominance: vector.dominance,
            intensity: intensity,
            labels: labels,
            toneHints: toneHints,
            appraisal: appraisal,
            sources: [resolvedSource],
            confidence: confidence,
            evidenceSummary: rawMood,
            userConfirmed: resolvedSource == .userSelected,
            rawInput: rawMood
        )
    }

    func draftFromJournalingStateOfMind(
        label: String,
        allLabels: [String] = [],
        associations: [String] = [],
        valence: Double? = nil,
        valenceClassification: String? = nil,
        kind: String? = nil,
        arousal: Double? = nil,
        dominance: Double? = nil,
        intensity: Double? = nil
    ) -> AffectSnapshotDraft {
        let normalizedLabels = orderedUnique((allLabels.isEmpty ? [label] : allLabels).compactMap(nonisolatedTrimmedOrNil))
        let rawMood = nonisolatedTrimmedOrNil(normalizedLabels.joined(separator: ", ")) ?? label
        var base = draft(
            rawMood: rawMood,
            userIntensity: nil,
            source: .journalSuggestionStateOfMind
        ) ?? AffectSnapshotDraft(rawInput: rawMood)
        base.sources = [.journalSuggestionStateOfMind]
        base.valence = valence ?? base.valence
        base.arousal = arousal
        base.dominance = dominance
        base.intensity = intensity ?? base.intensity
        base.confidence = max(base.confidence ?? 0.75, 0.8)
        base.evidenceSummary = [
            "Journaling Suggestion StateOfMind",
            normalizedLabels.isEmpty ? nil : "labels=\(normalizedLabels.joined(separator: ","))",
            associations.isEmpty ? nil : "associations=\(associations.joined(separator: ","))",
            valence.map { "valence=\($0)" },
            valenceClassification.map { "classification=\($0)" },
            kind.map { "kind=\($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: "; ")
        base.rawInput = rawMood
        base.userConfirmed = true
        return base
    }

    private func evidenceMetadata(from draft: AffectSnapshotDraft) -> [String: String] {
        var metadata: [String: String] = [:]
        if let rawInput = draft.rawInput?.trimmedOrNil { metadata["rawInput"] = rawInput }
        if !draft.labels.isEmpty { metadata["mappedLabels"] = draft.labels.map(\.rawValue).joined(separator: ",") }
        if let valence = draft.valence { metadata["valence"] = String(valence) }
        if let arousal = draft.arousal { metadata["arousal"] = String(arousal) }
        if let dominance = draft.dominance { metadata["dominance"] = String(dominance) }
        if let intensity = draft.intensity { metadata["intensity"] = String(intensity) }
        for component in (draft.evidenceSummary ?? "").split(separator: ";") {
            let pair = component.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            if pair.count == 2 {
                metadata[pair[0]] = pair[1]
            }
        }
        return metadata
    }

    private func labels(for normalized: String) -> [AffectLabel] {
        var labels: [AffectLabel] = []
        if contains(normalized, ["excited", "兴奋", "期待", "被点燃"]) { labels.append(.excited) }
        if contains(normalized, ["amazed", "惊叹"]) { labels.append(.amazed) }
        if contains(normalized, ["inspired", "灵感", "启发"]) { labels.append(.inspired) }
        if contains(normalized, ["proud", "自豪"]) { labels.append(.proud) }
        if contains(normalized, ["curious", "好奇"]) { labels.append(.curious) }
        if contains(normalized, ["brave", "勇敢"]) { labels.append(.brave) }
        if contains(normalized, ["confident", "自信"]) { labels.append(.confident) }
        if contains(normalized, ["content", "满足"]) { labels.append(.content) }
        if contains(normalized, ["happy", "开心"]) { labels.append(.happy) }
        if contains(normalized, ["hopeful", "有希望"]) { labels.append(.hopeful) }
        if contains(normalized, ["joyful", "喜悦"]) { labels.append(.joyful) }
        if contains(normalized, ["passionate", "热情"]) { labels.append(.passionate) }
        if contains(normalized, ["peaceful", "安宁"]) { labels.append(.peaceful) }
        if contains(normalized, ["satisfied", "满意"]) { labels.append(.satisfied) }
        if contains(normalized, ["calm", "平静", "安稳"]) { labels.append(.calm) }
        if contains(normalized, ["grateful", "感激", "感谢"]) { labels.append(.grateful) }
        if contains(normalized, ["relieved", "释然", "松了口气", "放下"]) { labels.append(.relieved) }
        if contains(normalized, ["warm", "温暖", "亲近"]) { labels.append(.warm) }
        if contains(normalized, ["angry", "生气"]) { labels.append(.angry) }
        if contains(normalized, ["annoyed", "恼"]) { labels.append(.annoyed) }
        if contains(normalized, ["ashamed", "羞愧"]) { labels.append(.ashamed) }
        if contains(normalized, ["disappointed", "失望"]) { labels.append(.disappointed) }
        if contains(normalized, ["discouraged", "泄气"]) { labels.append(.discouraged) }
        if contains(normalized, ["disgusted", "厌恶"]) { labels.append(.disgusted) }
        if contains(normalized, ["embarrassed", "尴尬"]) { labels.append(.embarrassed) }
        if contains(normalized, ["frustrated", "挫败"]) { labels.append(.frustrated) }
        if contains(normalized, ["guilty", "内疚"]) { labels.append(.guilty) }
        if contains(normalized, ["hopeless", "绝望"]) { labels.append(.hopeless) }
        if contains(normalized, ["irritated", "烦", "烦躁", "恼火"]) { labels.append(.irritated) }
        if contains(normalized, ["jealous", "嫉妒"]) { labels.append(.jealous) }
        if contains(normalized, ["anxious", "焦虑", "紧张", "害怕"]) { labels.append(.anxious) }
        if contains(normalized, ["tense", "绷", "压力", "紧绷"]) { labels.append(.tense) }
        if contains(normalized, ["overwhelmed", "崩溃", "太多", "overload"]) { labels.append(.overwhelmed) }
        if contains(normalized, ["scared", "害怕", "恐惧"]) { labels.append(.scared) }
        if contains(normalized, ["surprised", "惊讶"]) { labels.append(.surprised) }
        if contains(normalized, ["worried", "担心"]) { labels.append(.worried) }
        if contains(normalized, ["drained", "耗尽"]) { labels.append(.drained) }
        if contains(normalized, ["indifferent", "无所谓"]) { labels.append(.indifferent) }
        if contains(normalized, ["tired", "累", "疲惫", "困"]) { labels.append(.tired) }
        if contains(normalized, ["sad", "难过", "低落"]) { labels.append(.sad) }
        if contains(normalized, ["lonely", "孤独", "寂寞"]) { labels.append(.lonely) }
        if contains(normalized, ["numb", "麻木", "无感"]) { labels.append(.numb) }
        if contains(normalized, ["amused", "好笑", "笑死"]) { labels.append(.amused) }
        if contains(normalized, ["mock", "吐槽", "真服了", "无语"]) { labels.append(.mockFrustrated) }
        if contains(normalized, ["stressed", "stress", "压力"]) { labels.append(.stressed) }
        if contains(normalized, ["playful", "玩", "开玩笑"]) { labels.append(.playful) }
        if contains(normalized, ["uncertain", "不确定", "说不清"]) { labels.append(.uncertain) }
        return labels.isEmpty ? [.uncertain] : orderedUnique(labels)
    }

    private func toneHints(for normalized: String) -> [ToneHint] {
        var hints: [ToneHint] = []
        if contains(normalized, ["joking", "开玩笑", "玩笑", "好笑"]) { hints.append(.joking) }
        if contains(normalized, ["playful", "玩", "调侃"]) { hints.append(.playful) }
        if contains(normalized, ["sarcastic", "阴阳", "讽刺"]) { hints.append(.sarcastic) }
        if contains(normalized, ["venting", "吐槽", "发泄"]) { hints.append(.venting) }
        if contains(normalized, ["serious", "认真", "真的烦", "真烦", "real"]) { hints.append(.serious) }
        if contains(normalized, ["tender", "温柔", "亲近"]) { hints.append(.tender) }
        if contains(normalized, ["exhausted", "疲惫", "累"]) { hints.append(.exhausted) }
        if contains(normalized, ["uncertain", "不确定", "说不清"]) { hints.append(.uncertain) }
        return orderedUnique(hints)
    }

    private func vector(
        labels: [AffectLabel],
        toneHints: [ToneHint],
        normalizedText: String
    ) -> (valence: Double, arousal: Double, dominance: Double, intensity: Double) {
        if toneHints.contains(.joking) || toneHints.contains(.playful) {
            return (0.1, 0.6, 0.7, 0.55)
        }
        if labels.contains(.irritated) || labels.contains(.stressed) || labels.contains(.angry) || labels.contains(.frustrated) || toneHints.contains(.serious) {
            return (-0.7, 0.8, 0.25, 0.72)
        }
        if labels.contains(.anxious) || labels.contains(.tense) || labels.contains(.overwhelmed) || labels.contains(.worried) || labels.contains(.scared) {
            return (-0.55, 0.82, 0.25, 0.75)
        }
        if labels.contains(.tired) || labels.contains(.sad) || labels.contains(.lonely) || labels.contains(.numb) || labels.contains(.drained) || labels.contains(.hopeless) {
            return (-0.5, 0.25, 0.25, 0.5)
        }
        if labels.contains(.calm) || labels.contains(.relieved) || labels.contains(.warm) || labels.contains(.grateful) || labels.contains(.peaceful) || labels.contains(.content) || labels.contains(.satisfied) {
            return (0.65, 0.25, 0.72, 0.45)
        }
        if labels.contains(.excited) || labels.contains(.inspired) || labels.contains(.proud) || labels.contains(.curious) || labels.contains(.happy) || labels.contains(.joyful) || labels.contains(.hopeful) || labels.contains(.amazed) || labels.contains(.passionate) {
            return (0.75, 0.75, 0.68, 0.7)
        }
        if normalizedText.contains("neutral") || normalizedText.contains("普通") {
            return (0, 0.3, 0.5, 0.25)
        }
        return (0, 0.45, 0.45, 0.35)
    }

    private func confidence(labels: [AffectLabel], toneHints: [ToneHint], normalizedText: String) -> Double {
        if toneHints.contains(.uncertain) || labels == [.uncertain] {
            return 0.35
        }
        if isKnownChip(normalizedText) {
            return 0.78
        }
        if !toneHints.isEmpty && !labels.isEmpty {
            return 0.64
        }
        return 0.52
    }

    private func appraisal(
        labels: [AffectLabel],
        toneHints: [ToneHint],
        normalizedText: String
    ) -> AffectAppraisal? {
        if toneHints.contains(.joking) || toneHints.contains(.playful) {
            return AffectAppraisal(
                certainty: 0.55,
                control: 0.7,
                goalAlignment: .neutral,
                socialSafety: 0.85,
                copingPotential: 0.75
            )
        }
        if labels.contains(.irritated) || labels.contains(.stressed) || normalizedText.contains("blocked") || normalizedText.contains("卡") {
            return AffectAppraisal(
                certainty: 0.62,
                control: 0.2,
                goalAlignment: .blocked,
                socialSafety: 0.45,
                copingPotential: 0.35
            )
        }
        if labels.contains(.calm) || labels.contains(.relieved) {
            return AffectAppraisal(
                certainty: 0.7,
                control: 0.72,
                goalAlignment: .supported,
                socialSafety: 0.7,
                copingPotential: 0.72
            )
        }
        return nil
    }

    private func needsUserCheck(confidence: Double?, toneHints: [ToneHint]) -> Bool {
        (confidence ?? 0) < 0.5 || toneHints.contains(.uncertain)
    }

    private func isKnownChip(_ normalized: String) -> Bool {
        let known = Set(AffectLabel.allCases.map(\.rawValue) + ToneHint.allCases.map(\.rawValue))
        return known.contains(normalized)
    }

    private func contains(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0.lowercased()) }
    }

    private func nonisolatedTrimmedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func orderedUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        var result: [T] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}
