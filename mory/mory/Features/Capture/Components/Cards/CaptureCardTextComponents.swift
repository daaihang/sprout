import SwiftUI
import UIKit

struct CaptureCardCapsuleRow: View {
    let iconName: String
    var imageData: Data?
    let title: String
    let subtitle: String?
    let accent: Color
    var context: CaptureCardRenderContext?

    var body: some View {
        HStack(spacing: 10) {
            icon

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                if let subtitle = subtitle?.trimmedOrNil {
                    Text(subtitle)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(accent.opacity(0.1))
    }

    @ViewBuilder
    private var icon: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: iconDiameter, height: iconDiameter)
                .clipShape(Circle())
        } else {
            Image(systemName: iconName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: iconDiameter, height: iconDiameter)
                .background(accent, in: Circle())
        }
    }

    private var resolvedHeight: CGFloat? {
        guard let context else { return nil }
        let height = context.availableSize?.height ?? context.metrics.preferredSize.height
        guard height.isFinite, height > 0 else { return nil }
        return height
    }

    private var iconDiameter: CGFloat {
        guard let height = resolvedHeight else { return 42 }
        return max(34, min(42, height - 2 * leadingInset))
    }

    private var leadingInset: CGFloat {
        guard let height = resolvedHeight else { return 12 }
        let targetIconDiameter = max(34, min(42, height - 18))
        return max(8, (height - targetIconDiameter) / 2)
    }

    private var trailingInset: CGFloat {
        max(12, leadingInset)
    }

    private var symbolSize: CGFloat {
        iconDiameter >= 40 ? 18 : 16
    }
}

struct CaptureCardTextPanel: View {
    let iconName: String
    let title: String
    let detail: String?
    let metadata: String?
    let context: CaptureCardRenderContext
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(context.metrics.titleLineLimit)
            }

            if let detail = detail?.trimmedOrNil {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(context.metrics.detailLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if context.isDetailed, let metadata = metadata?.trimmedOrNil {
                Text(metadata)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(accent)
                    .lineLimit(context.metrics.metadataLineLimit)
            }
        }
        .padding(context.metrics.padding.edgeInsets)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(accent.opacity(0.08))
    }
}
