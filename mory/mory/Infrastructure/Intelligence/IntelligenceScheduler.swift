import Foundation

struct IntelligenceSchedulingResult: Sendable {
    let postAnalysisJob: IntelligenceJob
    let entityEnrichmentJobs: [IntelligenceJob]
    let questionGenerationJobs: [IntelligenceJob]
}

struct IntelligenceScheduler: Sendable {
    func schedulePostAnalysis(
        recordID: UUID,
        personEntityIDs: [UUID],
        now: Date = .now
    ) -> IntelligenceSchedulingResult {
        let orderedEntityIDs = Array(NSOrderedSet(array: personEntityIDs)) as? [UUID] ?? personEntityIDs
        return IntelligenceSchedulingResult(
            postAnalysisJob: IntelligenceJob(
                kind: .postAnalysis,
                targetType: .record,
                targetID: recordID,
                status: .pending,
                priority: 0.85,
                scheduledAt: now,
                updatedAt: now,
                requiresCloudAI: false
            ),
            entityEnrichmentJobs: orderedEntityIDs.map { entityID in
                IntelligenceJob(
                    kind: .entityEnrichment,
                    targetType: .entity,
                    targetID: entityID,
                    status: .pending,
                    priority: 0.72,
                    scheduledAt: now,
                    updatedAt: now,
                    requiresCloudAI: false
                )
            },
            questionGenerationJobs: orderedEntityIDs.map { entityID in
                IntelligenceJob(
                    kind: .clarificationQuestionGeneration,
                    targetType: .entity,
                    targetID: entityID,
                    status: .pending,
                    priority: 0.66,
                    scheduledAt: now,
                    updatedAt: now,
                    requiresCloudAI: false
                )
            }
        )
    }
}
