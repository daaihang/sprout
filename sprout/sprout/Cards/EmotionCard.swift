import SwiftUI

enum MoodType: String, CaseIterable {
    case happy, excited, grateful, calm, confused, anxious, sad, tired, angry

    var emoji: String {
        switch self {
        case .happy:    return "😊"
        case .excited:  return "🤩"
        case .grateful: return "🥰"
        case .calm:     return "😌"
        case .confused: return "😕"
        case .anxious:  return "😰"
        case .sad:      return "😢"
        case .tired:    return "😴"
        case .angry:    return "😤"
        }
    }

    var label: String {
        switch self {
        case .happy:    return localizedString("mood.happy", default: "Happy")
        case .excited:  return localizedString("mood.excited", default: "Excited")
        case .grateful: return localizedString("mood.grateful", default: "Grateful")
        case .calm:     return localizedString("mood.calm", default: "Calm")
        case .confused: return localizedString("mood.confused", default: "Confused")
        case .anxious:  return localizedString("mood.anxious", default: "Anxious")
        case .sad:      return localizedString("mood.sad", default: "Sad")
        case .tired:    return localizedString("mood.tired", default: "Tired")
        case .angry:    return localizedString("mood.angry", default: "Angry")
        }
    }

    var color: Color {
        switch self {
        case .happy:    return Color(red: 1.0, green: 0.82, blue: 0.1)
        case .excited:  return Color(red: 1.0, green: 0.5, blue: 0.1)
        case .grateful: return Color(red: 1.0, green: 0.4, blue: 0.65)
        case .calm:     return Color(red: 0.2, green: 0.75, blue: 0.7)
        case .confused: return Color(white: 0.55)
        case .anxious:  return Color(red: 0.9, green: 0.6, blue: 0.1)
        case .sad:      return Color(red: 0.3, green: 0.5, blue: 0.9)
        case .tired:    return Color(red: 0.5, green: 0.3, blue: 0.7)
        case .angry:    return Color(red: 0.9, green: 0.2, blue: 0.2)
        }
    }
}

struct EmotionCardData {
    var mood: MoodType = .happy
    var note: String = ""
    var intensity: Int = 3
}

struct EmotionCard: View {
    var data: EmotionCardData?
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let data {
                GeometryReader { geo in
                    contentView(data, metrics: CardLayoutMetrics(containerSize: geo.size))
                }
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .onTapGesture { onTap?() }
    }

    @ViewBuilder
    private func contentView(_ data: EmotionCardData, metrics: CardLayoutMetrics) -> some View {
        if metrics.isCompactHeight {
            HStack(spacing: 10) {
                Text(data.mood.emoji)
                    .font(.system(size: metrics.isCompactWidth ? 22 : 28))
                VStack(alignment: .leading, spacing: 1) {
                    Text(data.mood.label)
                        .font(.system(size: metrics.isCompactWidth ? 12 : 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    intensityDots(data.intensity, color: data.mood.color, dotSize: metrics.isCompactWidth ? 4 : 5)
                }
                Spacer()
            }
            .padding(metrics.isCompactWidth ? 10 : 14)
        } else if metrics.isMediumHeight {
            HStack(alignment: .top, spacing: 12) {
                Text(data.mood.emoji)
                    .font(.system(size: metrics.isWideWidth ? 44 : 38))
                VStack(alignment: .leading, spacing: 6) {
                    Text(data.mood.label)
                        .font(.system(size: metrics.isWideWidth ? 17 : 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    intensityDots(data.intensity, color: data.mood.color, dotSize: metrics.isWideWidth ? 8 : 6)
                    if !data.note.isEmpty && !metrics.isCompactWidth {
                        Text(data.note)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            .padding(metrics.isWideWidth ? 16 : 14)
        } else {
            ZStack {
                data.mood.color.opacity(0.08)
                VStack(alignment: .leading, spacing: 0) {
                    Text(data.mood.emoji)
                        .font(.system(size: metrics.isWideWidth ? 60 : 52))
                    Spacer()
                    Text(data.mood.label)
                        .font(.system(size: metrics.isWideWidth ? 20 : 18, weight: .semibold))
                        .foregroundStyle(.primary)
                    intensityDots(data.intensity, color: data.mood.color, dotSize: metrics.isWideWidth ? 9 : 8)
                        .padding(.top, 6)
                    if !data.note.isEmpty && metrics.isWideWidth {
                        Text(data.note)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .padding(.top, 8)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private func intensityDots(_ intensity: Int, color: Color, dotSize: CGFloat) -> some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= intensity ? color : color.opacity(0.2))
                    .frame(width: dotSize, height: dotSize)
            }
        }
    }

    @ViewBuilder
    private var placeholderView: some View {
        VStack(spacing: 8) {
            Text("😊")
                .font(.system(size: 28))
                .opacity(0.4)
            Text(localizedString("mood.placeholder", default: "Tap to log an emotion"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
