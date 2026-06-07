import SwiftUI
import UIKit

struct JournalingSuggestionCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureJournalingSuggestionCardPayload
    let context: CaptureCardRenderContext
    let accent: Color
    let highContrast: Bool

    var body: some View {
        if context.isSimple {
            CaptureCardCapsuleRow(
                iconName: "sparkles.rectangle.stack.fill",
                imageData: payload.thumbnailData,
                title: common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.journalingSuggestion"),
                subtitle: "\(payload.artifactCount) items",
                accent: accent,
                context: context
            )
        } else {
            cardBody
        }
    }

    private var cardBody: some View {
        ZStack(alignment: .bottomLeading) {
            background
            LinearGradient(
                colors: legibility.scrimColors,
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.title3.weight(.semibold))
                    Text("Journaling Suggestion")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                Text(common.title?.trimmedOrNil ?? "Journaling Suggestion")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(context.metrics.titleLineLimit)
                if context.isDetailed {
                    Text(common.detail)
                        .font(.caption.weight(.medium))
                        .lineLimit(context.metrics.detailLineLimit)
                }
                chips
            }
            .foregroundStyle(legibility.primaryText)
            .shadow(color: legibility.shadow, radius: 3, y: 1)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var background: some View {
        if let image = payload.thumbnailImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(colors: [.indigo.opacity(0.74), accent.opacity(0.52), .teal.opacity(0.42)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var chips: some View {
        HStack(spacing: 5) {
            ForEach(Array(summaryChips.enumerated()), id: \.offset) { _, chip in
                Label(chip.label, systemImage: chip.icon)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private var summaryChips: [(icon: String, label: String)] {
        var chips: [(String, String)] = []
        if payload.livePhotoCount > 0 { chips.append(("livephoto", "\(payload.livePhotoCount)")) }
        if payload.videoCount > 0 { chips.append(("video.fill", "\(payload.videoCount)")) }
        if payload.photoCount > 0 { chips.append(("photo.fill", "\(payload.photoCount)")) }
        if payload.locationCount > 0 { chips.append(("mappin.and.ellipse", "\(payload.locationCount)")) }
        if payload.musicCount > 0 { chips.append(("music.note", "\(payload.musicCount)")) }
        if payload.affectCount > 0 { chips.append(("heart.text.square", "\(payload.affectCount)")) }
        if chips.isEmpty { chips.append(("tray.full.fill", "\(payload.artifactCount)")) }
        return Array(chips.prefix(4))
    }

    private var legibility: CaptureCardLegibility {
        CaptureCardLegibility.imageData(payload.thumbnailData, highContrast: highContrast)
    }
}

private extension CaptureJournalingSuggestionCardPayload {
    var thumbnailImage: UIImage? {
        guard let thumbnailData else { return nil }
        return UIImage(data: thumbnailData)
    }
}
