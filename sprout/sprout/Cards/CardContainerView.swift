import SwiftUI

// MARK: - Card Container View

struct CardContainerView: View {
    let container: CardContainer

    var body: some View {
        container.content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(GridConfig.containerPadding)
            .rotationEffect(.degrees(container.rotationDegrees))
            .scaleEffect(container.scale)
            .zIndex(Double(container.zIndex))
            .animation(.spring(duration: 0.34, bounce: 0.18), value: container.span)
    }
}
