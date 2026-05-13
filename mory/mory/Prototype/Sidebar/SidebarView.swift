import SwiftUI

struct SidebarView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection

    private let scenarios = DemoScenarios.all()

    var body: some View {
        List(selection: routeBinding) {
            Section("Workspace") {
                ForEach(PrototypeRoute.allCases) { route in
                    Text(route.title)
                        .tag(route)
                }
            }

            Section("Boards") {
                ForEach(workspace.boards) { board in
                    Button {
                        selection.route = .boards
                        selection.activeBoardID = board.id
                        selection.selectedEntity = .board(board.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(board.title)
                            Text(board.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Graph") {
                Button {
                    selection.route = .entities
                    selection.selectedEntity = workspace.sortedEntityNodes().first.map { .entity($0.id) }
                } label: {
                    HStack {
                        Text("All Entities")
                        Spacer()
                        Text("\(workspace.entityNodes.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Temporal") {
                Button {
                    selection.route = .arcs
                    selection.selectedEntity = workspace.sortedTemporalArcs().first.map { .arc($0.id) }
                } label: {
                    HStack {
                        Text("All Arcs")
                        Spacer()
                        Text("\(workspace.temporalArcs.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Scenarios") {
                if scenarios.indices.contains(0) { scenarioButton(scenarios[0]) }
                if scenarios.indices.contains(1) { scenarioButton(scenarios[1]) }
                if scenarios.indices.contains(2) { scenarioButton(scenarios[2]) }
            }
        }
        .listStyle(.sidebar)
    }

    private var routeBinding: Binding<PrototypeRoute?> {
        Binding(
            get: { selection.route },
            set: { newValue in
                if let newValue {
                    selection.route = newValue
                }
            }
        )
    }

    @ViewBuilder
    private func scenarioButton(_ scenario: DemoScenario) -> some View {
        Button {
            workspace.reload(from: scenario)
            selection.route = .boards
            selection.activeBoardID = scenario.boards.first?.id
            selection.selectedEntity = scenario.boards.first.map { .board($0.id) }
        } label: {
            HStack {
                Text(scenario.name)
                if scenario.name == workspace.scenarioName {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
