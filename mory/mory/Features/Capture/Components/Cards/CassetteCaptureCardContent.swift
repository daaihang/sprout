import SwiftUI

struct CassetteCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureAudioCardPayload

    var body: some View {
        ZStack {
            cassetteBody

            VStack(spacing: 0) {
                reelArea
                    .frame(height: 52)

                labelArea
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 210, height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    private var cassetteBody: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(bodyGradient)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.brown.opacity(0.3), lineWidth: 1)
            }
    }

    private var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.82, green: 0.76, blue: 0.66), Color(red: 0.74, green: 0.67, blue: 0.56)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var reelArea: some View {
        HStack(spacing: 40) {
            reelCircle(radius: 18)
            reelCircle(radius: 18)
        }
        .padding(.top, 8)
    }

    private func reelCircle(radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.2))
                .frame(width: radius * 2, height: radius * 2)

            Circle()
                .strokeBorder(Color(white: 0.35), lineWidth: 1.5)
                .frame(width: radius * 2, height: radius * 2)

            Circle()
                .fill(Color(white: 0.3))
                .frame(width: radius * 0.7, height: radius * 0.7)

            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(white: 0.4))
                    .frame(width: 2, height: radius * 0.5)
                    .offset(y: -radius * 0.35)
                    .rotationEffect(.degrees(Double(i) * 120))
            }
        }
    }

    private var labelArea: some View {
        VStack(spacing: 3) {
            Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.audio"))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .foregroundStyle(Color(white: 0.15))

            HStack(spacing: 6) {
                if let duration = payload.durationSeconds {
                    Text(formattedDuration(duration))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color(white: 0.35))
                }

                if let detail = common.detail.trimmedOrNil {
                    Text(detail)
                        .font(.system(size: 9))
                        .foregroundStyle(Color(white: 0.35))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.white.opacity(0.5))
                .padding(.horizontal, 12)
        )
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
