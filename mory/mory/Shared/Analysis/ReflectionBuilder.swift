import Foundation

struct ReflectionBuilder {
    func build(
        record: RecordShell,
        artifacts: [Artifact],
        analysis: RecordAnalysisSnapshot
    ) -> ReflectionSnapshot {
        ReflectionSnapshot(
            type: .record,
            title: "Record Reflection",
            body: analysis.insight,
            sourceRecordIDs: [record.id],
            sourceArtifactIDs: artifacts.map(\.id),
            sourceEntityIDs: analysis.entities.map(\.id),
            createdAt: analysis.createdAt
        )
    }
}
