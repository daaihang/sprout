import Foundation

@main
struct AnalyzeResponseMapperTestRunner {
    static func main() {
        let mapper = AnalyzeResponseMapper()
        let now = Date(timeIntervalSince1970: 1_715_596_800)
        let recordID = UUID()

        let response = SproutAnalyzeResponse(
            tags: [" transition ", "career", "Transition"],
            emotion: .init(label: " reflective ", intensity: 2, confidence: 0.8),
            entities: [
                .init(kind: "person", name: " Lina ", canonicalName: nil, confidence: 0.91),
                .init(kind: "location", name: " Shanghai ", canonicalName: "上海", confidence: 0.88),
                .init(kind: "topic", name: "Transition", canonicalName: nil, confidence: 0.86),
                .init(kind: "choice", name: "Leave Job", canonicalName: "Leave Job", confidence: 0.77),
                .init(kind: "theme", name: "transition", canonicalName: nil, confidence: 0.84),
                .init(kind: "people", name: "Lina", canonicalName: nil, confidence: 0.65)
            ],
            candidateEdges: [],
            insight: "Fallback insight",
            summary: " Preferred summary ",
            salienceScore: 0.74,
            retrievalTerms: [" transition ", "Lina", "career"],
            reflectionHint: " Watch for repeated hesitation around leaving. ",
            followUp: .init(question: " What should I do next? ")
        )

        let snapshot = mapper.map(response: response, recordID: recordID, createdAt: now)

        expect(snapshot.recordID == recordID, "preserves record id")
        expect(snapshot.summary == "Preferred summary", "prefers summary over insight")
        expect(snapshot.insight == "Preferred summary", "keeps legacy insight accessor")
        expect(snapshot.emotionInterpretation == "reflective", "trims emotion interpretation")
        expect(snapshot.emotionLabel == "reflective", "keeps legacy emotion accessor")
        expect(snapshot.followUpCandidates == ["What should I do next?"], "maps follow-up candidates")
        expect(snapshot.followUpQuestion == "What should I do next?", "keeps legacy follow-up accessor")
        expect(snapshot.salienceScore == 0.74, "maps salience score")
        expect(snapshot.reflectionHint == "Watch for repeated hesitation around leaving.", "trims reflection hint")
        expect(snapshot.entityMentions.count == 4, "maps four normalized entity kinds and deduplicates aliases")
        expect(snapshot.entities.count == 4, "keeps legacy entity accessor")
        expect(snapshot.entityMentions.contains(where: { $0.kind == .person && $0.name == "Lina" }), "maps person entity")
        expect(snapshot.entityMentions.contains(where: { $0.kind == .place && $0.name == "上海" }), "maps place entity from location alias")
        expect(snapshot.entityMentions.contains(where: { $0.kind == .theme && $0.name == "Transition" }), "maps theme entity from topic alias")
        expect(snapshot.entityMentions.contains(where: { $0.kind == .decision && $0.name == "Leave Job" }), "maps decision entity")
        expect(snapshot.themes == ["transition", "career"], "deduplicates tags and appends theme names once")
        expect(snapshot.tags == ["transition", "career"], "keeps legacy tag accessor")
        expect(snapshot.retrievalTerms == ["transition", "Lina", "career", "上海", "Leave Job"], "merges retrieval terms with tags and entity names")
        expect(snapshot.candidateEdges.isEmpty, "maps empty candidate edges")

        print("analyze_response_mapper_test: PASS")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("analyze_response_mapper_test: FAIL - \(message)\n", stderr)
            Foundation.exit(1)
        }
    }
}
