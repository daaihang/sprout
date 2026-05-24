import SwiftUI

struct TodoCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureTodoCardPayload
    let accent: Color
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(accent)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.todo"))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(common.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(accent.opacity(0.08))
    }
}
