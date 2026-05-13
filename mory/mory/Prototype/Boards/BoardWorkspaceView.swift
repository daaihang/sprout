import SwiftUI

struct BoardWorkspaceView: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let board = activeBoard {
                BoardToolbarView(board: board)
                Divider()
                CompositionCanvasView(
                    board: board,
                    items: workspace.compositionItems(for: board.id)
                )
            } else {
                ContentUnavailableView("No Board Selected", systemImage: "square.grid.2x2")
            }
        }
    }

    private var activeBoard: Board? {
        if let activeBoardID = selection.activeBoardID {
            return workspace.boards.first { $0.id == activeBoardID }
        }
        return workspace.boards.first
    }
}
