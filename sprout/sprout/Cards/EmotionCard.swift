import SwiftUI

struct EmotionCard: View {
    let size: CardSize

    var body: some View {
        Text("EmotionCard \(sizeName)")
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

struct EmotionCard_4x1: View {
    var body: some View { EmotionCard(size: .w4h1) }
}

struct EmotionCard_4x2: View {
    var body: some View { EmotionCard(size: .w4h2) }
}

struct EmotionCard_4x4: View {
    var body: some View { EmotionCard(size: .w4h4) }
}

#Preview {
    VStack(spacing: 12) {
        EmotionCard_4x1()
        EmotionCard_4x2()
        EmotionCard_4x4()
    }
}