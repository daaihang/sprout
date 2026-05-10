import SwiftUI

struct ActivityCard: View {
    let size: CardSize

    var body: some View {
        Text("ActivityCard \(sizeName)")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cardBackground()
    }

    private var sizeName: String {
        switch size {
        case .w4h1: return "4x1"
        case .w4h2: return "4x2"
        case .w4h4: return "4x4"
        default: return "unknown"
        }
    }
}

struct ActivityCard_4x1: View {
    var body: some View { ActivityCard(size: .w4h1) }
}

struct ActivityCard_4x2: View {
    var body: some View { ActivityCard(size: .w4h2) }
}

struct ActivityCard_4x4: View {
    var body: some View { ActivityCard(size: .w4h4) }
}


#Preview {
    VStack(spacing: 12) {
        ActivityCard_4x1()
        ActivityCard_4x2()
        ActivityCard_4x4()
    }
}