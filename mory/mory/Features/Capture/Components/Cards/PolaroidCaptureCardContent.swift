import SwiftUI
import UIKit

struct PolaroidCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CapturePhotoCardPayload

    var body: some View {
        VStack(spacing: 0) {
            photoArea
                .frame(width: 148, height: 148)
                .clipped()

            bottomLabel
                .frame(width: 148, height: 44)
        }
        .padding(EdgeInsets(top: 10, leading: 10, bottom: 4, trailing: 10))
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
                    .lineLimit(1)
            }
            if let metadata = common.metadata?.trimmedOrNil {
                Text(metadata)
                    .font(.system(size: 9, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
