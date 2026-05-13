import SwiftUI

struct CompositionCanvasView: View {
    @Environment(PrototypeSelectionStore.self) private var selection
    @Environment(PrototypeWorkspaceStore.self) private var workspace

    let board: Board
    let items: [CompositionItem]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.93, blue: 0.88),
                                Color(red: 0.89, green: 0.92, blue: 0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                ForEach(items) { item in
                    CompositionItemView(item: item)
                        .frame(
                            width: CGFloat(item.widthUnits) * 72,
                            height: CGFloat(item.heightUnits) * 72
                        )
                        .position(
                            x: resolvedPositionX(for: item, in: geometry.size),
                            y: resolvedPositionY(for: item, in: geometry.size)
                        )
                        .zIndex(Double(item.zIndex))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let x = min(max(value.location.x / max(geometry.size.width, 1), 0.06), 0.94)
                                    let y = min(max(value.location.y / max(geometry.size.height, 1), 0.08), 0.92)
                                    workspace.update(
                                        itemID: item.id,
                                        positionHint: .init(x: x, y: y)
                                    )
                                }
                        )
                        .onTapGesture {
                            selection.selectedEntity = .item(item.id)
                        }
                }
            }
            .padding(24)
        }
        .padding(20)
    }

    private func resolvedPositionX(for item: CompositionItem, in size: CGSize) -> CGFloat {
        max(80, min(CGFloat(item.positionHint.x) * size.width, size.width - 80))
    }

    private func resolvedPositionY(for item: CompositionItem, in size: CGSize) -> CGFloat {
        max(80, min(CGFloat(item.positionHint.y) * size.height, size.height - 80))
    }
}
