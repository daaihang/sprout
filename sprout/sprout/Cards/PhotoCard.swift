import SwiftUI

struct PhotoCard: View {
    let size: CardSize

    var body: some View {
        Text("PhotoCard \(sizeName)")
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

struct PhotoCard_4x1: View {
    var body: some View { PhotoCard(size: .w4h1) }
}

struct PhotoCard_4x2: View {
    var body: some View { PhotoCard(size: .w4h2) }
}

struct PhotoCard_4x4: View {
    var body: some View { PhotoCard(size: .w4h4) }
}


#Preview {
    VStack(spacing: 12) {
        PhotoCard_4x1()
        PhotoCard_4x2()
        PhotoCard_4x4()
    }
}