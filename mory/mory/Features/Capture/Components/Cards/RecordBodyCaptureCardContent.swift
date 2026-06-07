import SwiftUI

struct RecordBodyCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CapturePromptCardPayload
    let context: CaptureCardRenderContext
    let accent: Color

    var body: some View {
        if context.isSimple {
            CaptureCardCapsuleRow(
                iconName: "note.text",
                title: common.title?.trimmedOrNil ?? payload.prompt,
                subtitle: common.metadata?.trimmedOrNil,
                accent: accent,
                context: context
            )
        } else {
            CaptureCardTextPanel(
                iconName: "note.text",
                title: common.title?.trimmedOrNil ?? payload.prompt,
                detail: payload.answer?.trimmedOrNil ?? common.detail,
                metadata: common.metadata,
                context: context,
                accent: accent
            )
        }
    }
}

struct PromptCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CapturePromptCardPayload
    let context: CaptureCardRenderContext
    let accent: Color

    var body: some View {
        CaptureCardTextPanel(
            iconName: "questionmark.bubble",
            title: payload.prompt.trimmedOrNil ?? common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.prompt"),
            detail: payload.answer?.trimmedOrNil ?? common.detail.trimmedOrNil,
            metadata: common.metadata,
            context: context,
            accent: accent
        )
    }
}

struct PersonCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CapturePersonContextCardPayload
    let context: CaptureCardRenderContext
    let accent: Color

    var body: some View {
        if context.isSimple {
            CaptureCardCapsuleRow(
                iconName: "person.crop.circle",
                imageData: payload.photoData,
                title: payload.name.trimmedOrNil ?? common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.person"),
                subtitle: common.detail.trimmedOrNil,
                accent: accent,
                context: context
            )
        } else {
            HStack(alignment: .top, spacing: 12) {
                CaptureCardCapsuleRow(
                    iconName: "person.crop.circle",
                    imageData: payload.photoData,
                    title: payload.name.trimmedOrNil ?? common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.person"),
                    subtitle: nil,
                    accent: accent
                )
                .frame(width: 62, height: 62)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(payload.name.trimmedOrNil ?? common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.person"))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(context.metrics.titleLineLimit)
                    Text(common.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(context.metrics.detailLineLimit)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(context.metrics.padding.edgeInsets)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(accent.opacity(0.08))
        }
    }
}

struct AffectCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureAffectCardPayload
    let context: CaptureCardRenderContext
    let accent: Color

    var body: some View {
        CaptureCardCapsuleRow(
            iconName: affectIconName,
            title: common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.affect"),
            subtitle: affectSubtitle,
            accent: affectColor,
            context: context
        )
    }

    private var affectSubtitle: String? {
        payload.sourceDescription?.trimmedOrNil
            ?? payload.valence.map { String(format: "valence %.2f", $0) }
            ?? common.detail.trimmedOrNil
    }

    private var affectIconName: String {
        guard let valence = payload.valence else { return "heart.text.square" }
        if valence > 0.25 { return "face.smiling" }
        if valence < -0.25 { return "cloud.rain" }
        return "circle.lefthalf.filled"
    }

    private var affectColor: Color {
        guard let valence = payload.valence else { return accent }
        if valence > 0.25 { return .green }
        if valence < -0.25 { return .indigo }
        return accent
    }
}

struct BundleCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureJournalingSuggestionCardPayload
    let context: CaptureCardRenderContext
    let accent: Color
    let highContrast: Bool

    var body: some View {
        if context.isSimple {
            CaptureCardCapsuleRow(
                iconName: "square.stack.3d.up.fill",
                imageData: payload.thumbnailData,
                title: common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.bundle"),
                subtitle: "\(payload.artifactCount) items",
                accent: accent,
                context: context
            )
        } else {
            CaptureCardTextPanel(
                iconName: "square.stack.3d.up.fill",
                title: common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.bundle"),
                detail: bundleDetail,
                metadata: common.metadata,
                context: context,
                accent: accent
            )
        }
    }

    private var bundleDetail: String {
        let parts = [
            countPart(payload.photoCount, "photo"),
            countPart(payload.videoCount, "video"),
            countPart(payload.livePhotoCount, "live"),
            countPart(payload.locationCount, "place"),
            countPart(payload.musicCount, "music"),
            countPart(payload.promptCount, "prompt"),
            countPart(payload.affectCount, "mood"),
        ].compactMap { $0 }
        return parts.joined(separator: " · ").trimmedOrNil
            ?? common.detail.trimmedOrNil
            ?? "\(payload.artifactCount) items"
    }

    private func countPart(_ count: Int, _ label: String) -> String? {
        count > 0 ? "\(count) \(label)" : nil
    }
}
