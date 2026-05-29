import SwiftUI

struct CassetteCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureAudioCardPayload
    var sizeToken: MemoryCardSizeToken = .tape
    var density: MemoryCardContentDensity = .regular
    var metrics: MemoryCardObjectMetrics = .resolve(recipe: .cassette, sizeToken: .tape)

    var body: some View {
        switch normalizedSize {
        case .strip:
            stripBody
        case .banner:
            bannerBody
        default:
            tapeBody
        }
    }

    private var normalizedSize: MemoryCardSizeToken {
        MemoryCardRecipeLayoutPolicy.normalizedSize(sizeToken, for: .cassette)
    }

    private var stripBody: some View {
        HStack(spacing: 10) {
            miniReelPair
                .frame(width: 58, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(titleText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.16))
                    .lineLimit(metrics.titleLineLimit)

                Text(durationOrKind)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.38))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(metrics.padding.edgeInsets)
        .frame(width: metrics.preferredSize.width, height: metrics.preferredSize.height)
        .background(cassetteShell(cornerRadius: 10))
        .overlay(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(white: 0.18).opacity(0.24))
                .frame(width: 18, height: 36)
                .padding(.trailing, 10)
        }
        .cassetteShadow()
    }

    private var tapeBody: some View {
        ZStack {
            cassetteShell(cornerRadius: 10)

            VStack(spacing: 8) {
                HStack(spacing: 34) {
                    reelCircle(radius: 18)
                    windowBridge
                    reelCircle(radius: 18)
                }
                .padding(.top, 10)

                labelArea(lineLimit: 1, showsMetadata: false)
                    .padding(.horizontal, 13)
                    .padding(.bottom, 10)
            }
        }
        .frame(width: metrics.preferredSize.width, height: metrics.preferredSize.height)
        .cassetteShadow()
    }

    private var bannerBody: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                cassetteShell(cornerRadius: 10)
                VStack(spacing: 7) {
                    HStack(spacing: 26) {
                        reelCircle(radius: 16)
                        windowBridge
                        reelCircle(radius: 16)
                    }
                    .padding(.top, 10)

                    labelArea(lineLimit: 1, showsMetadata: false)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 9)
                }
            }
            .frame(width: bannerCassetteSize.width, height: bannerCassetteSize.height)

            transcriptSlip
                .frame(width: bannerSlipSize.width, height: bannerSlipSize.height)
        }
        .frame(width: metrics.preferredSize.width, height: metrics.preferredSize.height, alignment: .center)
        .cassetteShadow()
    }

    private var transcriptSlip: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("TRANSCRIPT")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(labelAccent.opacity(0.82))
                .tracking(1.0)

            Text(detailText)
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundStyle(Color(white: 0.18))
                .lineLimit(metrics.detailLineLimit)

            Spacer(minLength: 0)

            Text(metadataText)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(white: 0.44))
                .lineLimit(metrics.metadataLineLimit)
        }
        .padding(12)
        .background(Color(red: 0.97, green: 0.95, blue: 0.87), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.brown.opacity(0.16), lineWidth: 0.7)
        }
        .rotationEffect(.degrees(1.2))
    }

    private func labelArea(lineLimit: Int, showsMetadata: Bool) -> some View {
        VStack(spacing: 3) {
            Text(titleText)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(metrics.titleLineLimit)
                .foregroundStyle(Color(white: 0.15))

            HStack(spacing: 6) {
                Text(durationOrKind)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.36))

                Text(detailText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(white: 0.36))
                    .lineLimit(min(lineLimit, metrics.detailLineLimit))
            }

            if showsMetadata {
                Text(metadataText)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.46))
                    .lineLimit(metrics.metadataLineLimit)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(labelPaper, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(labelAccent.opacity(0.46))
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .padding(.horizontal, 10)
        }
    }

    private var miniReelPair: some View {
        HStack(spacing: 8) {
            reelCircle(radius: 12)
            reelCircle(radius: 12)
        }
    }

    private var windowBridge: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color(white: 0.12).opacity(0.78))
            .frame(width: 42, height: 16)
            .overlay {
                Capsule()
                    .fill(Color(white: 0.34))
                    .frame(width: 26, height: 4)
            }
    }

    private var bannerContentHeight: CGFloat {
        min(220, max(96, metrics.preferredSize.height * 0.92))
    }

    private var bannerCassetteSize: CGSize {
        let width = min(220, max(158, metrics.preferredSize.width * 0.50))
        return CGSize(width: width, height: bannerContentHeight)
    }

    private var bannerSlipSize: CGSize {
        let width = max(144, metrics.preferredSize.width - bannerCassetteSize.width - 12)
        return CGSize(width: width, height: bannerContentHeight)
    }

    private func reelCircle(radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.18))
                .frame(width: radius * 2, height: radius * 2)

            Circle()
                .strokeBorder(Color(white: 0.38), lineWidth: 1.4)
                .frame(width: radius * 2, height: radius * 2)

            Circle()
                .fill(Color(white: 0.32))
                .frame(width: radius * 0.72, height: radius * 0.72)

            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(white: 0.45))
                    .frame(width: 2, height: radius * 0.52)
                    .offset(y: -radius * 0.34)
                    .rotationEffect(.degrees(Double(index) * 120))
            }
        }
    }

    private func cassetteShell(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(bodyGradient)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.brown.opacity(0.28), lineWidth: 1)
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: 18) {
                    screwDot
                    Spacer(minLength: 0)
                    screwDot
                }
                .padding(.horizontal, 13)
                .padding(.bottom, 9)
            }
    }

    private var screwDot: some View {
        Circle()
            .fill(Color.brown.opacity(0.24))
            .frame(width: 4, height: 4)
    }

    private var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.86, green: 0.80, blue: 0.68),
                Color(red: 0.72, green: 0.65, blue: 0.53)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var labelPaper: Color {
        Color(red: 0.98, green: 0.95, blue: 0.84)
    }

    private var labelAccent: Color {
        Color(red: 0.62, green: 0.32, blue: 0.24)
    }

    private var titleText: String {
        common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.audio")
    }

    private var detailText: String {
        common.detail.trimmedOrNil ?? String(localized: "capture.card.kind.audio")
    }

    private var metadataText: String {
        common.metadata?.trimmedOrNil ?? durationOrKind
    }

    private var durationOrKind: String {
        if let duration = payload.durationSeconds {
            return formattedDuration(duration)
        }
        return "VOICE"
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private extension View {
    func cassetteShadow() -> some View {
        self
            .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.06), radius: 7, y: 4)
    }
}
