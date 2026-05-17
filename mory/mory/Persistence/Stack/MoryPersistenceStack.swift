import SwiftData

@MainActor
struct MoryPersistenceStack {
    static let schema = Schema([
        UserSettingsPreferenceStore.self,
        QualityTuningPreferenceStore.self,
        HomeBoardPreferenceStore.self,
        RecordShellStore.self,
        ArtifactStore.self,
        BoardStore.self,
        CompositionStore.self,
        CompositionItemStore.self,
        EntityNodeStore.self,
        EntityEdgeStore.self,
        ArtifactEntityLinkStore.self,
        RecordAnalysisSnapshotStore.self,
        MemoryPipelineStatusStore.self,
        ReflectionSnapshotStore.self,
        TemporalArcStore.self,
    ])

    static func makeSharedModelContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(
            "MoryV1",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create Mory model container: \(error)")
        }
    }
}
