import SwiftUI

struct HomePullToOpenPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct HomePullToOpenProbe: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: HomePullToOpenPreferenceKey.self,
                    value: geometry.frame(in: .named("homeScrollArea")).minY
                )
        }
        .frame(height: 0)
    }
}
