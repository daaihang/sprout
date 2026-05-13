import Foundation

@main
struct AnalysisEntityMatcherTestRunner {
    static func main() {
        let matcher = AnalysisEntityMatcher()
        let now = Date(timeIntervalSince1970: 1_715_596_800)
        let entity = EntityNode(
            kind: .person,
            displayName: "Lina",
            canonicalName: "Lin A",
            summary: "Lina",
            createdAt: now,
            updatedAt: now,
            confidence: 0.9
        )

        let matchingAnalysis = RecordAnalysisSnapshot(
            recordID: UUID(),
            summary: "Lina appears in this memory.",
            themes: ["transition"],
            emotionInterpretation: "reflective",
            followUpCandidates: [],
            entityMentions: [
                EntityReference(kind: .person, name: " lina ", confidence: 0.91),
                EntityReference(kind: .theme, name: "transition", confidence: 0.88)
            ],
            createdAt: now
        )

        let nonMatchingAnalysis = RecordAnalysisSnapshot(
            recordID: UUID(),
            summary: "Someone else is mentioned.",
            themes: ["work"],
            emotionInterpretation: "focused",
            followUpCandidates: [],
            entityMentions: [
                EntityReference(kind: .person, name: "Marcus", confidence: 0.8)
            ],
            createdAt: now.addingTimeInterval(60)
        )

        expect(matcher.matches(entity: entity, analysis: matchingAnalysis), "matches normalized person names")
        expect(!matcher.matches(entity: entity, analysis: nonMatchingAnalysis), "does not match unrelated analyses")
        expect(matcher.matchedReference(entity: entity, analysis: matchingAnalysis)?.name.trimmingCharacters(in: .whitespacesAndNewlines) == "lina", "returns matching reference")

        print("analysis_entity_matcher_test: PASS")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("analysis_entity_matcher_test: FAIL - \(message)\n", stderr)
            Foundation.exit(1)
        }
    }
}
