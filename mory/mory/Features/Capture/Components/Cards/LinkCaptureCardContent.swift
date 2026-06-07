import SwiftUI

struct LinkCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureLinkCardPayload
    let context: CaptureCardRenderContext
    let accent: Color

    var body: some View {
        if context.isSimple {
            CaptureCardCapsuleRow(
                iconName: "safari.fill",
                imageData: payload.thumbnailData,
                title: linkTitle,
                subtitle: linkHeader,
                accent: accent,
                context: context
            )
        } else {
            CaptureCardTextPanel(
                iconName: "safari.fill",
                title: linkTitle,
                detail: [linkHeader, linkDetail].compactMap { $0 }.joined(separator: "\n"),
                metadata: nil,
                context: context,
                accent: accent
            )
        }
    }

    private var linkHeader: String {
        common.metadata?.trimmedOrNil ?? URL(string: common.detail)?.host() ?? String(localized: "capture.card.kind.link")
    }

    private var linkTitle: String {
        let title = common.title?.trimmedOrNil
        if let title, !sameField(title, linkHeader) {
            return title
        }
        return linkHeader
    }

    private var linkDetail: String? {
        let detail = common.detail.trimmedOrNil
        guard let detail, !sameField(detail, linkTitle), !sameField(detail, linkHeader) else {
            return nil
        }
        return detail
    }

    private func sameField(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare(rhs.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }
}
