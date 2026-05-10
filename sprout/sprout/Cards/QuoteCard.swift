import SwiftUI

struct QuoteCard: View {
    let size: CardSize

    var body: some View {
        Text("QuoteCard \(sizeName)")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)
            .frame(width: size.width, height: size.height)
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

struct QuoteCard_4x1: View {
    var body: some View { QuoteCard(size: .w4h1) }
}

struct QuoteCard_4x2: View {
    var body: some View { QuoteCard(size: .w4h2) }
}

struct QuoteCard_4x4: View {
    var body: some View { QuoteCard(size: .w4h4) }
}

#Preview {
    VStack(spacing: 12) {
        QuoteCard_4x1()
        QuoteCard_4x2()
        QuoteCard_4x4()
    }
}