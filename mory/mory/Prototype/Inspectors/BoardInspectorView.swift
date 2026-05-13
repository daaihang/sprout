import SwiftUI

struct BoardInspectorView: View {
    let board: Board

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Board")
                .font(.headline)
            LabeledContent("Title", value: board.title)
            LabeledContent("Kind", value: board.kind.rawValue)
            LabeledContent("Subtitle", value: board.subtitle)
            Spacer()
        }
    }
}
