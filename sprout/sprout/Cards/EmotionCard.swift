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
        case .happy:    return "开心"
        case .excited:  return "兴奋"
        case .grateful: return "感恩"
        case .calm:     return "平静"
        case .confused: return "困惑"
        case .anxious:  return "焦虑"
        case .sad:      return "难过"
        case .tired:    return "疲惫"
        case .angry:    return "生气"
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
    let size: CardSize
    var data: EmotionCardData?
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let data {
                contentView(data)
            } else {
                placeholderView
            }
        }
        .frame(width: size.width, height: size.height)
        .cardBackground()
        .onTapGesture { onTap?() }
    }

    @ViewBuilder
    private func contentView(_ data: EmotionCardData) -> some View {
        if size == .w4h1 {
            HStack(spacing: 10) {
                Text(data.mood.emoji)
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 1) {
                    Text(data.mood.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    intensityDots(data.intensity, color: data.mood.color, dotSize: 5)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        } else if size == .w4h2 {
            HStack(alignment: .top, spacing: 12) {
                Text(data.mood.emoji)
                    .font(.system(size: 42))
                VStack(alignment: .leading, spacing: 6) {
                    Text(data.mood.label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    intensityDots(data.intensity, color: data.mood.color, dotSize: 7)
                    if !data.note.isEmpty {
                        Text(data.note)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            .padding(14)
        } else {
            ZStack {
                data.mood.color.opacity(0.08)
                VStack(alignment: .leading, spacing: 0) {
                    Text(data.mood.emoji)
                        .font(.system(size: 56))
                    Spacer()
                    Text(data.mood.label)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                    intensityDots(data.intensity, color: data.mood.color, dotSize: 9)
                        .padding(.top, 6)
                    if !data.note.isEmpty {
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
        VStack(spacing: size == .w4h1 ? 4 : 8) {
            Text("😊")
                .font(.system(size: size == .w4h1 ? 22 : 34))
                .opacity(0.4)
            if size != .w4h1 {
                Text("点击记录心情")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct EmotionCard_4x1: View {
    var data: EmotionCardData?
    var onTap: (() -> Void)?
    var body: some View { EmotionCard(size: .w4h1, data: data, onTap: onTap) }
}

struct EmotionCard_4x2: View {
    var data: EmotionCardData?
    var onTap: (() -> Void)?
    var body: some View { EmotionCard(size: .w4h2, data: data, onTap: onTap) }
}

struct EmotionCard_4x4: View {
    var data: EmotionCardData?
    var onTap: (() -> Void)?
    var body: some View { EmotionCard(size: .w4h4, data: data, onTap: onTap) }
}

#Preview {
    VStack(spacing: 12) {
        EmotionCard_4x1(data: EmotionCardData(mood: .happy, intensity: 4))
        EmotionCard_4x2(data: EmotionCardData(mood: .calm, note: "今天状态不错，感觉很平静。", intensity: 3))
        EmotionCard_4x4(data: EmotionCardData(mood: .grateful, note: "感谢今天遇到的每一件小事，生活真的很美好。值得珍惜。", intensity: 5))
    }
    .frame(width: 393)
    .padding()
}
