import SwiftUI

struct StatusCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureStatusCardPayload
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundStyle(statusColor)

            Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.status"))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Text(common.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(statusColor.opacity(0.08))
    }

    private var statusIcon: String {
        switch common.state {
        case .loading:
            return "hourglass"
        case .error:
            return "exclamationmark.triangle.fill"
        case .disabled:
            return "minus.circle"
        case .normal:
            return "info.circle"
        }
    }

    private var statusColor: Color {
        switch common.state {
        case .loading:
            return .blue
        case .error:
            return .red
        case .disabled:
            return .secondary
        case .normal:
            return .secondary
        }
    }
}
