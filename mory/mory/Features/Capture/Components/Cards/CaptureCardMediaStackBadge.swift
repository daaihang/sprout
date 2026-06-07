import SwiftUI

struct CaptureCardMediaStackBadge: View {
    let count: Int

    var body: some View {
        if count > 1 {
            Text("+\(count - 1)")
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.54), in: Capsule())
                .padding(10)
        }
    }
}
