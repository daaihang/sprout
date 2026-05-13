import Foundation
import Observation

enum PrototypeRoute: String, CaseIterable, Identifiable, Sendable {
    case boards
    case records
    case artifacts
    case entities
    case arcs
    case reflections
    case debug

    var id: String { rawValue }

    var title: String {
        switch self {
        case .boards: "Boards"
        case .records: "Records"
        case .artifacts: "Artifacts"
        case .entities: "Entities"
        case .arcs: "Arcs"
        case .reflections: "Reflections"
        case .debug: "Debug"
        }
    }
}

enum SelectedEntity: Equatable, Sendable {
    case board(UUID)
    case record(UUID)
    case artifact(UUID)
    case entity(UUID)
    case arc(UUID)
    case reflection(UUID)
    case item(UUID)
}

@Observable
final class PrototypeSelectionStore {
    var route: PrototypeRoute
    var selectedEntity: SelectedEntity?
    var activeBoardID: UUID?

    init(route: PrototypeRoute = .boards, selectedEntity: SelectedEntity? = nil, activeBoardID: UUID? = nil) {
        self.route = route
        self.selectedEntity = selectedEntity
        self.activeBoardID = activeBoardID
    }

    static func makeDefault() -> PrototypeSelectionStore {
        let scenario = DemoScenarios.relationshipArc()
        return PrototypeSelectionStore(
            route: .boards,
            selectedEntity: .board(scenario.boards[0].id),
            activeBoardID: scenario.boards[0].id
        )
    }
}
