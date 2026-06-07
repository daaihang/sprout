import SwiftUI

struct StatusCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureStatusCardPayload
    let context: CaptureCardRenderContext
    let accent: Color

    var body: some View {
        if context.isSimple {
            CaptureCardCapsuleRow(
                iconName: statusIcon,
                title: common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.status"),
                subtitle: common.detail.trimmedOrNil,
                accent: statusColor,
                context: context
            )
        } else {
            CaptureCardTextPanel(
                iconName: statusIcon,
                title: common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.status"),
                detail: common.detail,
                metadata: common.metadata,
                context: context,
                accent: statusColor
            )
        }
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
