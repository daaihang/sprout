import SwiftUI

struct PhaseReflectionCardData {
    var title: String
    var body: String
    var phaseTitle: String
    var dateText: String
    var recordCount: Int

    var badgeText: String {
        "\(recordCount) memories"
    }
}

struct PhaseReflectionCard: View {
    @Environment(AppLocalization.self) private var localization
    let data: PhaseReflectionCardData?

    var body: some View {
        Group {
            if let data {
                reflectionBody(data)
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: GridConfig.cardCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func reflectionBody(_ data: PhaseReflectionCardData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localization.string("common.phase_reflection_badge", default: "REFLECTION"))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(Color.white.opacity(0.82))

                    Text(data.phaseTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 38, height: 38)
                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }

            Spacer(minLength: 14)

            Text(data.body)
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .lineLimit(6)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 16)

            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(data.badgeText.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(Color.white.opacity(0.76))

                    Text(data.dateText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(data.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .lineLimit(1)
            }
        }
        .padding(18)
    }

    private var placeholderView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.72))
            Text(localization.string("common.no_reflection_yet", default: "No reflection yet"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: GridConfig.cardCornerRadius, style: .continuous))
    }

    private var cardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.12, blue: 0.36),
                    Color(red: 0.30, green: 0.17, blue: 0.47),
                    Color(red: 0.12, green: 0.23, blue: 0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.14),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 220
            )
        }
    }
}
