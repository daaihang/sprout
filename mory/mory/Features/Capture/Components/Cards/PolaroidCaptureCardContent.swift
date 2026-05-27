import SwiftUI
import UIKit

struct PolaroidCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CapturePhotoCardPayload
    var sizeToken: MemoryCardSizeToken = .square
    var density: MemoryCardContentDensity = .regular
    var metrics: MemoryCardObjectMetrics = .resolve(recipe: .polaroid, sizeToken: .square)

    var body: some View {
        VStack(spacing: 0) {
            photoArea
                .frame(width: photoLength, height: photoLength)
                .clipped()

            bottomLabel
                .frame(width: photoLength, height: labelHeight)
        }
        .padding(EdgeInsets(top: paperInset, leading: paperInset, bottom: 4, trailing: paperInset))
        .background(paperColor)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .rotationEffect(.degrees(tiltAngle))
    }

    @ViewBuilder
    private var photoArea: some View {
        if let data = payload.thumbnailData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(.systemGray5)
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.quaternary)
            }
        }
    }

    private var bottomLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title = common.title?.trimmedOrNil {
                Text(title)
                    .font(.system(size: 11, design: .serif))
                    .lineLimit(metrics.titleLineLimit)
            }
            if metrics.density != .compact, let metadata = common.metadata?.trimmedOrNil {
                Text(metadata)
                    .font(.system(size: 9, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(metrics.metadataLineLimit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }

    @Environment(\.colorScheme) private var colorScheme

    private var paperColor: Color {
        colorScheme == .dark ? Color(white: 0.88) : .white
    }

    private var photoLength: CGFloat {
        min(metrics.preferredSize.width - (paperInset * 2), metrics.preferredSize.height - labelHeight - paperInset - 4)
    }

    private var labelHeight: CGFloat {
        metrics.density == .expanded ? 58 : 44
    }

    private var paperInset: CGFloat {
        metrics.padding.top
    }

    private var tiltAngle: Double {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in common.id.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        let normalized = Double(hash % 1000) / 1000.0
        return (normalized - 0.5) * 8
    }
}
