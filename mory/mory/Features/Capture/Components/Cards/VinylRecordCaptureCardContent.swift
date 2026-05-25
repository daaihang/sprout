import SwiftUI

struct VinylRecordCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureMusicCardPayload
    let accent: Color

    var body: some View {
        ZStack(alignment: .leading) {
            record
                .offset(x: 54)

            sleeve
        }
        .frame(width: 230, height: 150)
    }

    private var sleeve: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(sleeveGradient)
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.music"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .foregroundStyle(.white)

                if let artist = common.detail.trimmedOrNil {
                    Text(artist)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
            .padding(12)
        }
        .frame(width: 140, height: 140)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }

    private var record: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.black.opacity(0.95), .black.opacity(0.82), .black],
                        center: .center,
                        startRadius: 8,
                        endRadius: 70
                    )
                )

            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .stroke(.white.opacity(0.07), lineWidth: 1)
                    .padding(CGFloat(index) * 10 + 8)
            }

            Circle()
                .fill(accent.opacity(0.9))
                .frame(width: 34, height: 34)

            Circle()
                .fill(.black.opacity(0.72))
                .frame(width: 8, height: 8)
        }
        .frame(width: 132, height: 132)
        .shadow(color: .black.opacity(0.18), radius: 7, y: 3)
    }

    private var sleeveGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(0.95),
                Color(red: 0.18, green: 0.18, blue: 0.2),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
