import SwiftUI
import UIKit

struct PersonContextCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CapturePersonContextCardPayload
    let accent: Color
    var metrics: MemoryCardObjectMetrics = .resolve(recipe: .personCard, sizeToken: .card)

    var body: some View {
        VStack(spacing: metrics.sizeToken == .strip ? 0 : 9) {
            portrait
                .frame(width: portraitSize.width, height: portraitSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(spacing: 3) {
                Text(payload.name.trimmedOrNil ?? common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.person"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.18))
                    .lineLimit(metrics.titleLineLimit)

                Text(common.detail)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.42))
                    .lineLimit(metrics.detailLineLimit)
            }
        }
        .padding(metrics.padding.edgeInsets)
        .frame(width: metrics.preferredSize.width, height: metrics.preferredSize.height)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent.opacity(0.76))
                .padding(8)
        }
        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    private var portraitSize: CGSize {
        metrics.sizeToken == .strip
            ? CGSize(width: 54, height: 46)
            : CGSize(width: 102, height: 98)
    }

    @ViewBuilder
    private var portrait: some View {
        if let data = payload.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [accent.opacity(0.2), Color(.systemGray5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 46, weight: .regular))
                    .foregroundStyle(accent.opacity(0.75))
            }
        }
    }
}

struct BundlePacketCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let thumbnailData: Data?
    let itemCount: Int?
    let accent: Color
    var metrics: MemoryCardObjectMetrics = .resolve(recipe: .bundlePacket, sizeToken: .card)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            packetLayer(offset: CGSize(width: 17, height: -10), rotation: 5, opacity: 0.62)
            packetLayer(offset: CGSize(width: 9, height: -5), rotation: -3, opacity: 0.78)
            envelope
        }
        .frame(width: metrics.preferredSize.width, height: metrics.preferredSize.height)
    }

    private var envelope: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.88, green: 0.80, blue: 0.64))
                .overlay {
                    envelopeFlap
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.brown.opacity(0.2), lineWidth: 0.8)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.journalingSuggestion"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.2))
                    .lineLimit(metrics.titleLineLimit)

                Text(common.detail)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.36))
                    .lineLimit(metrics.detailLineLimit)

                Text(countText)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent.opacity(0.8))
                    .padding(.top, 2)
            }
            .padding(metrics.padding.edgeInsets)
        }
        .frame(width: metrics.preferredSize.width - 24, height: metrics.preferredSize.height - 28)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    private func packetLayer(offset: CGSize, rotation: Double, opacity: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white.opacity(opacity))

            if let thumbnailData, let image = UIImage(data: thumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(5)
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.42))
            }
        }
        .frame(width: metrics.sizeToken == .square ? 112 : 92, height: metrics.sizeToken == .square ? 104 : 84)
        .offset(offset)
        .rotationEffect(.degrees(rotation))
    }

    private var envelopeFlap: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.45))
                path.addLine(to: CGPoint(x: proxy.size.width, y: 0))
            }
            .stroke(Color.brown.opacity(0.18), lineWidth: 1)
        }
    }

    private var countText: String {
        if let itemCount {
            return "\(itemCount) ITEMS"
        }
        return common.metadata?.trimmedOrNil ?? "BUNDLE"
    }
}

struct MoodSwatchCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureAffectCardPayload?
    let accent: Color
    var sizeToken: MemoryCardSizeToken = .stamp
    var density: MemoryCardContentDensity = .compact
    var metrics: MemoryCardObjectMetrics = .resolve(recipe: .affectCard, sizeToken: .stamp)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            swatch
                .frame(height: metrics.sizeToken == .stamp ? 42 : 50)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.affect"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.18))
                .lineLimit(metrics.titleLineLimit)

            Text(common.detail)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.4))
                .lineLimit(metrics.detailLineLimit)
        }
        .padding(metrics.padding.edgeInsets)
        .frame(width: metrics.preferredSize.width, height: metrics.preferredSize.height, alignment: .leading)
        .background(Color(red: 0.96, green: 0.96, blue: 0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    private var swatch: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [moodColor.opacity(0.92), moodColor.opacity(0.38)],
                startPoint: .leading,
                endPoint: .trailing
            )

            Rectangle()
                .fill(.white.opacity(0.38))
                .frame(width: intensityWidth, height: 7)
                .clipShape(Capsule())
                .padding(9)
        }
    }

    private var moodColor: Color {
        guard let valence = payload?.valence else { return accent }
        if valence >= 0.25 { return .green }
        if valence <= -0.25 { return .purple }
        return .orange
    }

    private var intensityWidth: CGFloat {
        let normalized = abs(payload?.valence ?? 0.45)
        return max(32, min(112, 44 + CGFloat(normalized) * 68))
    }
}

struct PlainSystemNoteCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let accent: Color
    var metrics: MemoryCardObjectMetrics = .resolve(recipe: .statusNote, sizeToken: .stamp)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.status"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.18))
                    .lineLimit(metrics.titleLineLimit)
            }

            Text(common.detail)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.42))
                .lineLimit(metrics.detailLineLimit)
        }
        .padding(metrics.padding.edgeInsets)
        .frame(width: metrics.preferredSize.width, height: metrics.preferredSize.height, alignment: .topLeading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.8)
        }
    }
}
