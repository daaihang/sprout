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
        AdaptiveCardRoot(content: emotionContent) {
            placeholderView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .onTapGesture { onTap?() }
    }

    private var emotionContent: AdaptiveCardContent? {
        guard let data else { return nil }

        let intensityText = localizedString(
            "mood.intensity",
            default: "Intensity %d/5",
            arguments: [data.intensity]
        )

        return AdaptiveCardContent(
            preferredLayout: data.note.isEmpty ? .metricFocus : .stackedInfo,
            accent: data.mood.color,
            visual: .emoji(data.mood.emoji, tint: data.mood.color),
            title: data.mood.label,
            subtitle: intensityText,
            body: data.note.isEmpty ? nil : data.note,
            badge: AdaptiveCardBadge(text: "\(data.intensity)/5", systemImage: "sparkles"),
            progress: AdaptiveCardProgress(
                value: Double(data.intensity) / 5,
                label: localizedString("mood.intensity_label", default: "Intensity"),
                trailingText: "\(data.intensity)/5"
            )
        )
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
