import SwiftUI

struct LinkCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureLinkCardPayload
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "safari.fill")
                    .font(.title3)
                    .foregroundStyle(accent)
                Text(linkHeader)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(linkTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            if let linkDetail {
                Text(linkDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(accent.opacity(0.08))
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
