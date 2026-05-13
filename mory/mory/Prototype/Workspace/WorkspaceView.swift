import SwiftUI

struct WorkspaceView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } content: {
            mainContent
        } detail: {
            InspectorPane()
        }
        .navigationTitle("Mory Prototype")
    }

    @ViewBuilder
    private var mainContent: some View {
        switch selection.route {
        case .boards:
            BoardWorkspaceView()
        case .records:
            RecordsListView(records: workspace.records)
        case .artifacts:
            ArtifactsListView(artifacts: workspace.artifacts)
        case .entities:
            EntitiesListView()
        case .arcs:
            TemporalArcsListView(arcs: workspace.sortedTemporalArcs())
        case .reflections:
            ReflectionsListView(reflections: workspace.reflections)
        case .debug:
            AnalyzeDebugPanel()
        }
    }
}
