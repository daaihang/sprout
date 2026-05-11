import SwiftUI

// MARK: - Card Container

struct CardContainer: Identifiable {
    let id: String
    let span: ContainerSpan
    let rotationDegrees: Double  // -5 ~ 5
    let scale: Double            // 0.95 ~ 1.05
    let zIndex: Int
    let content: AnyView

    init(id: String = UUID().uuidString, span: ContainerSpan, rotationDegrees: Double = 0, scale: Double = 1, zIndex: Int = 0, content: AnyView) {
        self.id = id
        self.span = span
        self.rotationDegrees = rotationDegrees
        self.scale = scale
        self.zIndex = zIndex
        self.content = content
    }
}

// MARK: - Sticker Effect Generator

func stickerSeed(for id: String) -> UInt64 {
    id.utf8.reduce(UInt64(1469598103934665603)) { partial, byte in
        (partial ^ UInt64(byte)) &* 1099511628211
    }
}

func stickerRotation(for id: String) -> Double {
    let normalized = Double(stickerSeed(for: id) % 1000) / 999.0
    return -3.0 + normalized * 6.0
}

func stickerScale(for id: String) -> Double {
    let normalized = Double((stickerSeed(for: id) / 1000) % 1000) / 999.0
    return 0.98 + normalized * 0.04
}
