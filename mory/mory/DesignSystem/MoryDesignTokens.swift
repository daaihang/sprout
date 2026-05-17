import SwiftUI

enum MorySpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
}

enum MoryCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
}

struct MorySurfaceStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(MorySpacing.large)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: MoryCornerRadius.medium, style: .continuous))
    }
}

extension View {
    func morySurface() -> some View {
        modifier(MorySurfaceStyle())
    }
}
