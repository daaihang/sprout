import SwiftUI

struct HomeBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            stops: gradientStops,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gradientStops: [Gradient.Stop] {
        if colorScheme == .dark {
            return [
                .init(color: Color(red: 0.08, green: 0.10, blue: 0.16), location: 0.00),
                .init(color: Color(red: 0.10, green: 0.11, blue: 0.18), location: 0.45),
                .init(color: Color(red: 0.08, green: 0.12, blue: 0.10), location: 1.00),
            ]
        }

        return [
            .init(color: Color(red: 0.78, green: 0.91, blue: 0.97), location: 0.00),
            .init(color: Color(red: 0.88, green: 0.93, blue: 0.99), location: 0.45),
            .init(color: Color(red: 0.92, green: 0.96, blue: 0.92), location: 1.00),
        ]
    }
}

