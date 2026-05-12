import SwiftUI

struct CardLayoutMetrics {
    let containerSize: CGSize

    var isCompactWidth: Bool { containerSize.width < 150 }
    var isRegularWidth: Bool { containerSize.width >= 150 && containerSize.width < 240 }
    var isWideWidth: Bool { containerSize.width >= 240 }

    var isCompactHeight: Bool { containerSize.height < 90 }
    var isMediumHeight: Bool { containerSize.height >= 90 && containerSize.height < 150 }
    var isTallHeight: Bool { containerSize.height >= 150 }

    var isLandscape: Bool { containerSize.width >= containerSize.height * 1.15 }
    var isPortrait: Bool { containerSize.height > containerSize.width * 1.15 }

    var shortSide: CGFloat { min(containerSize.width, containerSize.height) }
    var longSide: CGFloat { max(containerSize.width, containerSize.height) }
    var aspectRatio: CGFloat {
        guard containerSize.height > 0 else { return 1 }
        return containerSize.width / containerSize.height
    }

    var recommendedInset: CGFloat {
        max(10, min(18, shortSide * 0.12))
    }

    var contentSize: CGSize {
        CGSize(
            width: max(containerSize.width - recommendedInset * 2, 0),
            height: max(containerSize.height - recommendedInset * 2, 0)
        )
    }
}
