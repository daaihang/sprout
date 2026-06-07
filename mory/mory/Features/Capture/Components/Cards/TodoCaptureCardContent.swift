import SwiftUI

struct TodoCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureTodoCardPayload
    let context: CaptureCardRenderContext
    let accent: Color
    let isSelected: Bool

    var body: some View {
        if context.isSimple {
            CaptureCardCapsuleRow(
                iconName: isSelected ? "checkmark.circle.fill" : "circle",
                title: common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.todo"),
                subtitle: common.detail.trimmedOrNil,
                accent: accent
            )
        } else {
            CaptureCardTextPanel(
                iconName: isSelected ? "checkmark.circle.fill" : "circle",
                title: common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.todo"),
                detail: common.detail,
                metadata: common.metadata,
                context: context,
                accent: accent
            )
        }
    }
}
