import SwiftUI

struct InspectorPane: View {
    @Environment(PrototypeSelectionStore.self) private var selection
    @Environment(PrototypeWorkspaceStore.self) private var workspace

    var body: some View {
        Group {
            if let analysis = selectedAnalysis {
                AnalysisInspectorView(analysis: analysis)
            } else {
            switch selection.selectedEntity {
            case let .board(id):
                if let board = workspace.boards.first(where: { $0.id == id }) {
                    BoardInspectorView(board: board)
                } else {
                    emptyState
                }
            case let .record(id):
                if let record = workspace.records.first(where: { $0.id == id }) {
                    RecordInspectorView(record: record)
                } else {
                    emptyState
                }
            case let .artifact(id):
                if let artifact = workspace.artifacts.first(where: { $0.id == id }) {
                    ArtifactInspectorView(artifact: artifact)
                } else {
                    emptyState
                }
            case let .entity(id):
                if let entity = workspace.entityNodes.first(where: { $0.id == id }) {
                    EntityInspectorView(entity: entity)
                } else {
                    emptyState
                }
            case let .arc(id):
                if let arc = workspace.temporalArc(for: id) {
                    TemporalArcInspectorView(arc: arc)
                } else {
                    emptyState
                }
            case let .reflection(id):
                if let reflection = workspace.reflections.first(where: { $0.id == id }) {
                    ReflectionInspectorView(reflection: reflection)
                } else {
                    emptyState
                }
            case let .item(id):
                if let item = workspace.items.first(where: { $0.id == id }) {
                    CompositionItemInspectorView(item: item)
                } else {
                    emptyState
                }
            case .none:
                emptyState
            }
            }
        }
        .padding(18)
    }

    private var emptyState: some View {
        ContentUnavailableView("Inspector", systemImage: "sidebar.right")
    }

    private var selectedAnalysis: RecordAnalysisSnapshot? {
        guard let lastAnalyzedRecordID = workspace.lastAnalyzedRecordID else { return nil }
        return workspace.analysis(for: lastAnalyzedRecordID)
    }
}
