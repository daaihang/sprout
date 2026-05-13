import SwiftUI

struct BoardToolbarView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection

    let board: Board
    private let scenarios = DemoScenarios.all()

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(board.title)
                    .font(.title3.weight(.semibold))
                Text(board.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu("Switch Scenario") {
                if scenarios.indices.contains(0) { scenarioMenuButton(scenarios[0]) }
                if scenarios.indices.contains(1) { scenarioMenuButton(scenarios[1]) }
                if scenarios.indices.contains(2) { scenarioMenuButton(scenarios[2]) }
            }

            Label("Composition", systemImage: "square.on.square.dashed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.thinMaterial)
    }

    private func scenarioMenuButton(_ scenario: DemoScenario) -> some View {
        Button(scenario.name) {
            workspace.reload(from: scenario)
            selection.route = .boards
            selection.activeBoardID = scenario.boards.first?.id
            selection.selectedEntity = scenario.boards.first.map { .board($0.id) }
        }
    }
}
