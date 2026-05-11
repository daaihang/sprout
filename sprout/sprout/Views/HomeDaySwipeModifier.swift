import SwiftUI

struct HomeDaySwipeModifier: ViewModifier {
    let isEnabled: Bool
    let onNavigateDay: (Int) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        if value.translation.width < -40 {
                            onNavigateDay(+1)
                        } else if value.translation.width > 40 {
                            onNavigateDay(-1)
                        }
                    }
            )
        } else {
            content
        }
    }
}
