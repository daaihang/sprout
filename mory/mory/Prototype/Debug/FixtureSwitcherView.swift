import SwiftUI

struct FixtureSwitcherView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection

    private let scenarios = DemoScenarios.all()

    var body: some View {
        Menu("Switch Scenario") {
            if scenarios.indices.contains(0) { scenarioButton(scenarios[0]) }
            if scenarios.indices.contains(1) { scenarioButton(scenarios[1]) }
            if scenarios.indices.contains(2) { scenarioButton(scenarios[2]) }
        }
    }

    private func scenarioButton(_ scenario: DemoScenario) -> some View {
        Button(scenario.name) {
            workspace.reload(from: scenario)
            selection.route = .boards
            selection.activeBoardID = scenario.boards.first?.id
            selection.selectedEntity = scenario.boards.first.map { .board($0.id) }
        }
    }
}
