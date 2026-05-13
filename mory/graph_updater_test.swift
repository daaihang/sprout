import Foundation

@main
struct GraphUpdaterTestRunner {
    static func main() {
        let updater = GraphUpdater()
        let insightsBuilder = GraphInsightsBuilder()
        let arcBuilder = TemporalArcCandidateBuilder()
        let arcPromoter = TemporalArcPromoter()
        let mergeEngine = TemporalArcMergeEngine()
        let now = Date(timeIntervalSince1970: 1_715_596_800)
        let artifactID = UUID()
        let personID = UUID()
        let themeID = UUID()

        let analysis = RecordAnalysisSnapshot(
            recordID: UUID(),
            tags: ["relationship", "transition"],
            emotionLabel: "reflective",
            insight: "Test insight",
            followUpQuestion: nil,
            entities: [
                EntityReference(id: personID, kind: .person, name: "Lina", confidence: 0.9),
                EntityReference(id: themeID, kind: .theme, name: "transition", confidence: 0.8)
            ],
            createdAt: now
        )

        let first = updater.apply(
            analysis: analysis,
            linkedArtifactIDs: [artifactID],
            linkedRecordIDs: [analysis.recordID],
            existingEntityNodes: [],
            existingEntityEdges: [],
            existingArtifactEntityLinks: []
        )

        expect(first.entityNodes.count == 2, "creates entity nodes")
        expect(first.artifactEntityLinks.count == 2, "creates artifact links")
        expect(first.entityEdges.count == 1, "creates a relationship edge")
        expect(first.entityEdges.first?.evidenceCount == 1, "initial edge evidence count is 1")
        expect(first.entityEdges.first?.relationKind == .relatedTo, "person-theme relation resolves to relatedTo")
        expect(first.entityEdges.first?.sourceArtifactIDs == [artifactID], "persists edge artifact evidence")
        expect(first.entityEdges.first?.sourceRecordIDs == [analysis.recordID], "persists edge record evidence")

        let second = updater.apply(
            analysis: analysis,
            linkedArtifactIDs: [artifactID],
            linkedRecordIDs: [analysis.recordID],
            existingEntityNodes: first.entityNodes,
            existingEntityEdges: first.entityEdges,
            existingArtifactEntityLinks: first.artifactEntityLinks
        )

        expect(second.entityNodes.count == 2, "deduplicates entity nodes")
        expect(second.artifactEntityLinks.count == 2, "deduplicates artifact links")
        expect(second.entityEdges.count == 1, "reuses existing edge")
        expect(second.entityEdges.first?.evidenceCount == 2, "increments edge evidence count")
        expect(abs((second.entityEdges.first?.weight ?? 0) - 1.2) < 0.0001, "increments edge weight")
        expect(second.entityEdges.first?.sourceArtifactIDs.count == 1, "deduplicates edge artifact evidence")
        expect(second.entityEdges.first?.sourceRecordIDs.count == 1, "deduplicates edge record evidence")

        let decisionAnalysis = RecordAnalysisSnapshot(
            recordID: UUID(),
            tags: ["decision", "career"],
            emotionLabel: "tense",
            insight: "Decision test",
            followUpQuestion: nil,
            entities: [
                EntityReference(id: UUID(), kind: .person, name: "Marcus", confidence: 0.9),
                EntityReference(id: UUID(), kind: .decision, name: "job_offer", confidence: 0.95)
            ],
            createdAt: now.addingTimeInterval(60)
        )

        let decisionResult = updater.apply(
            analysis: decisionAnalysis,
            linkedArtifactIDs: [UUID()],
            linkedRecordIDs: [decisionAnalysis.recordID],
            existingEntityNodes: [],
            existingEntityEdges: [],
            existingArtifactEntityLinks: []
        )

        expect(decisionResult.entityEdges.first?.relationKind == .decidedAt, "person-decision relation resolves to decidedAt")

        let placeThemeAnalysis = RecordAnalysisSnapshot(
            recordID: UUID(),
            tags: ["arrival"],
            emotionLabel: "unsettled",
            insight: "Place theme test",
            followUpQuestion: nil,
            entities: [
                EntityReference(id: UUID(), kind: .place, name: "Jing'an", confidence: 0.9),
                EntityReference(id: UUID(), kind: .theme, name: "arrival", confidence: 0.85)
            ],
            createdAt: now.addingTimeInterval(120)
        )

        let placeThemeResult = updater.apply(
            analysis: placeThemeAnalysis,
            linkedArtifactIDs: [UUID()],
            linkedRecordIDs: [placeThemeAnalysis.recordID],
            existingEntityNodes: [],
            existingEntityEdges: [],
            existingArtifactEntityLinks: []
        )

        expect(placeThemeResult.entityEdges.first?.relationKind == .repeatedIn, "place-theme relation resolves to repeatedIn")

        let artifact = Artifact(
            id: artifactID,
            kind: .text,
            title: "Late-night walk",
            summary: "Walk summary",
            createdAt: now,
            updatedAt: now.addingTimeInterval(30),
            metadata: [:],
            entities: []
        )
        let record = RecordShell(
            id: analysis.recordID,
            createdAt: now,
            updatedAt: now.addingTimeInterval(40),
            rawText: "Test record",
            captureSource: .manual,
            artifactIDs: [artifactID]
        )
        let insights = insightsBuilder.build(
            entityNodes: first.entityNodes,
            entityEdges: first.entityEdges,
            artifactEntityLinks: first.artifactEntityLinks,
            records: [record],
            artifacts: [artifact],
            limit: 3
        )

        expect(insights.recentEntities.count == 2, "builds recent entity insights")
        expect(insights.hotEdges.count == 1, "builds hot edge insights")
        expect(insights.hotEdges.first?.relationKind == .relatedTo, "preserves edge relation in insights")
        expect(insights.recentEntities.first?.mentionCount == 1, "tracks mention counts in insights")

        let secondArtifact = Artifact(
            id: UUID(),
            kind: .photo,
            title: "River photo",
            summary: "Photo summary",
            createdAt: now.addingTimeInterval(3_600),
            updatedAt: now.addingTimeInterval(3_600),
            metadata: [:],
            entities: []
        )
        let unrelatedArtifact = Artifact(
            id: UUID(),
            kind: .text,
            title: "Work note",
            summary: "Ops checklist",
            textContent: "Deployment notes and task list",
            createdAt: now.addingTimeInterval(60 * 60 * 24 * 30),
            updatedAt: now.addingTimeInterval(60 * 60 * 24 * 30),
            metadata: [:],
            entities: []
        )
        let secondRecord = RecordShell(
            id: UUID(),
            createdAt: now.addingTimeInterval(7_200),
            updatedAt: now.addingTimeInterval(7_200),
            rawText: "Another reflective note",
            captureSource: .composer,
            artifactIDs: [secondArtifact.id]
        )
        let thirdRecord = RecordShell(
            id: UUID(),
            createdAt: now.addingTimeInterval(60 * 60 * 24 * 3),
            updatedAt: now.addingTimeInterval(60 * 60 * 24 * 3),
            rawText: "I kept circling back to Lina and what leaving means.",
            captureSource: .manual,
            artifactIDs: [secondArtifact.id]
        )
        let unrelatedRecord = RecordShell(
            id: UUID(),
            createdAt: now.addingTimeInterval(60 * 60 * 24 * 30),
            updatedAt: now.addingTimeInterval(60 * 60 * 24 * 30),
            rawText: "Reviewed deployment checklist for next sprint.",
            captureSource: .manual,
            artifactIDs: [unrelatedArtifact.id]
        )
        let secondAnalysis = RecordAnalysisSnapshot(
            recordID: secondRecord.id,
            tags: ["transition", "goodbye"],
            emotionLabel: "reflective",
            insight: "Arc candidate test",
            followUpQuestion: nil,
            entities: [
                EntityReference(id: personID, kind: .person, name: "Lina", confidence: 0.9),
                EntityReference(id: themeID, kind: .theme, name: "transition", confidence: 0.8)
            ],
            createdAt: now.addingTimeInterval(7_200)
        )
        let thirdAnalysis = RecordAnalysisSnapshot(
            recordID: thirdRecord.id,
            tags: ["transition", "distance"],
            emotionLabel: "heavy",
            insight: "Still unresolved",
            followUpQuestion: nil,
            entities: [
                EntityReference(id: personID, kind: .person, name: "Lina", confidence: 0.92),
                EntityReference(id: themeID, kind: .theme, name: "transition", confidence: 0.88)
            ],
            createdAt: now.addingTimeInterval(60 * 60 * 24 * 3)
        )
        let unrelatedAnalysis = RecordAnalysisSnapshot(
            recordID: unrelatedRecord.id,
            tags: ["work", "ops"],
            emotionLabel: "focused",
            insight: "Execution details",
            followUpQuestion: nil,
            entities: [
                EntityReference(id: UUID(), kind: .decision, name: "LaunchOps", confidence: 0.8)
            ],
            createdAt: now.addingTimeInterval(60 * 60 * 24 * 30)
        )
        let thirdArtifactLink = ArtifactEntityLink(
            artifactID: secondArtifact.id,
            entityID: personID,
            confidence: 0.9,
            source: "analysis",
            createdAt: now.addingTimeInterval(7_200)
        )
        let fourthArtifactLink = ArtifactEntityLink(
            artifactID: secondArtifact.id,
            entityID: themeID,
            confidence: 0.8,
            source: "analysis",
            createdAt: now.addingTimeInterval(7_200)
        )
        let unrelatedProjectID = unrelatedAnalysis.entities[0].id
        let unrelatedEntityNode = EntityNode(
            id: unrelatedProjectID,
            kind: .decision,
            displayName: "LaunchOps",
            createdAt: now.addingTimeInterval(60 * 60 * 24 * 30),
            updatedAt: now.addingTimeInterval(60 * 60 * 24 * 30),
            confidence: 0.8
        )
        let unrelatedArtifactLink = ArtifactEntityLink(
            artifactID: unrelatedArtifact.id,
            entityID: unrelatedProjectID,
            confidence: 0.8,
            source: "analysis",
            createdAt: now.addingTimeInterval(60 * 60 * 24 * 30)
        )

        let arcCandidates = arcBuilder.buildCandidates(
            records: [record, secondRecord, thirdRecord, unrelatedRecord],
            analyses: [analysis, secondAnalysis, thirdAnalysis, unrelatedAnalysis],
            artifacts: [artifact, secondArtifact, unrelatedArtifact],
            artifactEntityLinks: first.artifactEntityLinks + [thirdArtifactLink, fourthArtifactLink, unrelatedArtifactLink],
            entityNodes: first.entityNodes + [unrelatedEntityNode],
            maxCandidates: 3
        )

        expect(!arcCandidates.isEmpty, "builds temporal arc candidates")
        expect(arcCandidates.first?.recordIDs.count == 3, "candidate groups related records across nearby days")
        expect(arcCandidates.first?.themeLabels.contains("transition") == true, "candidate carries theme labels")
        expect(arcCandidates.first?.entityNames.contains("Lina") == true, "candidate carries entity names")
        expect((arcCandidates.first?.clusterStrength ?? 0) > 0.45, "candidate computes meaningful cluster strength")
        expect(arcCandidates.count >= 2, "separates unrelated records into a different candidate")
        expect(arcCandidates.first?.recordIDs.contains(unrelatedRecord.id) == false, "does not merge distant unrelated records")
        expect(arcCandidates.first?.dominantTheme == "transition", "candidate exposes dominant theme")

        if let firstCandidate = arcCandidates.first {
            let promotedArc = arcPromoter.promote(
                candidate: firstCandidate,
                analyses: [analysis, secondAnalysis, thirdAnalysis, unrelatedAnalysis],
                artifactEntityLinks: first.artifactEntityLinks + [thirdArtifactLink, fourthArtifactLink, unrelatedArtifactLink],
                entityNodes: first.entityNodes + [unrelatedEntityNode],
                createdAt: now.addingTimeInterval(60 * 60 * 24 * 31)
            )

            expect(promotedArc.status == .accepted, "promoted arc defaults to accepted")
            expect(promotedArc.sourceRecordIDs.count == 3, "promoted arc preserves source records")
            expect(promotedArc.sourceEntityIDs.count >= 2, "promoted arc resolves source entities")
            expect(promotedArc.summary.contains("phase"), "promoted arc generates summary")
            expect(promotedArc.title == firstCandidate.titleHint, "promoted arc inherits title hint")
            expect(promotedArc.status == .accepted, "arc lifecycle starts in accepted state")
            expect(promotedArc.linkedReflectionID == nil, "promoter leaves reflection linkage for store orchestration")

            let linkedRecordSet = Set(promotedArc.sourceRecordIDs)
            expect(linkedRecordSet.contains(record.id), "promoted arc keeps first source record")
            expect(linkedRecordSet.contains(secondRecord.id), "promoted arc keeps second source record")

            let linkedArtifactSet = Set(promotedArc.sourceArtifactIDs)
            expect(linkedArtifactSet.contains(artifact.id), "promoted arc keeps first source artifact")
            expect(linkedArtifactSet.contains(secondArtifact.id), "promoted arc keeps second source artifact")

            let generatedReflection = ReflectionSnapshot(
                type: .phase,
                title: promotedArc.title,
                body: promotedArc.summary,
                linkedTemporalArcID: promotedArc.id,
                sourceRecordIDs: promotedArc.sourceRecordIDs,
                sourceArtifactIDs: promotedArc.sourceArtifactIDs,
                sourceEntityIDs: promotedArc.sourceEntityIDs,
                createdAt: promotedArc.updatedAt
            )
            var linkedArc = promotedArc
            linkedArc.linkedReflectionID = generatedReflection.id

            expect(generatedReflection.linkedTemporalArcID == linkedArc.id, "phase reflection links back to arc")
            expect(linkedArc.linkedReflectionID == generatedReflection.id, "arc stores linked reflection id")

            let mergeCandidateArc = TemporalArc(
                title: "transition around Lina",
                summary: "Another nearby phase candidate.",
                status: .accepted,
                dominantTheme: "transition",
                dominantEntityName: "Lina",
                themeLabels: ["transition", "distance"],
                entityNames: ["Lina"],
                mergedFromArcIDs: [],
                mergedIntoArcID: nil,
                lastMergedAt: nil,
                sourceRecordIDs: [secondRecord.id, thirdRecord.id],
                sourceArtifactIDs: [secondArtifact.id],
                sourceEntityIDs: [personID, themeID],
                startDate: secondRecord.updatedAt,
                endDate: thirdRecord.updatedAt,
                intensityScore: 6.2,
                clusterStrength: 0.62,
                createdAt: now.addingTimeInterval(60 * 60 * 24 * 32),
                updatedAt: now.addingTimeInterval(60 * 60 * 24 * 32)
            )

            let preview = mergeEngine.previewMerge(base: linkedArc, candidate: mergeCandidateArc)
            expect(preview != nil, "merge engine surfaces overlap preview for nearby arcs")
            expect((preview?.overlapScore ?? 0) > 0.42, "merge overlap crosses merge threshold")

            let mergedArc = mergeEngine.merge(
                base: linkedArc,
                candidate: mergeCandidateArc,
                mergedAt: now.addingTimeInterval(60 * 60 * 24 * 33)
            )
            expect(mergedArc.sourceRecordIDs.count == 3, "merged arc deduplicates source records")
            expect(mergedArc.sourceArtifactIDs.count == 2, "merged arc combines source artifacts")
            expect(mergedArc.summary.contains("Merged phase"), "merged arc updates summary")
            expect(mergedArc.status == .accepted, "merged arc remains accepted")
            expect(mergedArc.mergedFromArcIDs.contains(mergeCandidateArc.id), "merged arc records provenance source ids")
            expect(mergedArc.lastMergedAt != nil, "merged arc stores merge timestamp")
        } else {
            expect(false, "expected first temporal arc candidate for promotion")
        }

        print("graph_updater_test: PASS")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("graph_updater_test: FAIL - \(message)\n", stderr)
            Foundation.exit(1)
        }
    }
}
