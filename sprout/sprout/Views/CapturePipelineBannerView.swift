import SwiftUI

struct CapturePipelineBannerView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(CapturePipelineStore.self) private var capturePipeline

    var body: some View {
        let presentation = bannerPresentation

        HStack(spacing: 12) {
            Image(systemName: presentation.symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(presentation.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let detail = presentation.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(presentation.tint.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }

    private var bannerPresentation: (symbolName: String, tint: Color, title: String, detail: String?) {
        switch capturePipeline.stage {
        case .idle:
            return ("circle", .clear, "", nil)
        case .saving:
            return (
                "square.and.arrow.down",
                .blue,
                t("capture.status.saving", "Saving"),
                capturePipeline.detailMessage
            )
        case .saved:
            return (
                "checkmark.circle",
                .green,
                t("capture.status.saved", "Saved locally"),
                capturePipeline.detailMessage
            )
        case .analyzing:
            return (
                "sparkles",
                .orange,
                t("capture.status.analyzing", "Analyzing"),
                capturePipeline.detailMessage
            )
        case .analyzed:
            return (
                "checkmark.seal",
                .green,
                t("capture.status.analyzed", "Analysis ready"),
                capturePipeline.detailMessage
            )
        case .analysisUnavailable:
            return (
                "exclamationmark.bubble",
                .yellow,
                t("capture.status.unavailable", "Saved without AI analysis"),
                capturePipeline.detailMessage
            )
        case .failed:
            return (
                "exclamationmark.triangle",
                .red,
                t("capture.status.failed", "Capture pipeline failed"),
                capturePipeline.detailMessage
            )
        }
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}
