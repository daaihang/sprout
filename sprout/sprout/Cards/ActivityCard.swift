import SwiftUI

enum ActivityType: String, CaseIterable {
    case steps, running, cycling, workout, sleep, meditation, swimming, yoga

    var sfSymbol: String {
        switch self {
        case .steps: return "figure.walk"
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .workout: return "dumbbell.fill"
        case .sleep: return "bed.double.fill"
        case .meditation: return "brain.head.profile"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.mind.and.body"
        }
    }

    var label: String {
        switch self {
        case .steps: return localizedString("activity.type.steps", default: "Steps")
        case .running: return localizedString("activity.type.running", default: "Running")
        case .cycling: return localizedString("activity.type.cycling", default: "Cycling")
        case .workout: return localizedString("activity.type.workout", default: "Strength Training")
        case .sleep: return localizedString("activity.type.sleep", default: "Sleep")
        case .meditation: return localizedString("activity.type.meditation", default: "Meditation")
        case .swimming: return localizedString("activity.type.swimming", default: "Swimming")
        case .yoga: return localizedString("activity.type.yoga", default: "Yoga")
        }
    }

    var defaultUnit: String {
        switch self {
        case .steps: return localizedString("activity.unit.step", default: "steps")
        case .running, .cycling: return "km"
        case .workout, .meditation, .yoga: return "min"
        case .sleep: return "hr"
        case .swimming: return "m"
        }
    }

    var color: Color {
        switch self {
        case .steps: return .green
        case .running: return .orange
        case .cycling: return .blue
        case .workout: return .red
        case .sleep: return .purple
        case .meditation: return .teal
        case .swimming: return .cyan
        case .yoga: return .pink
        }
    }
}

struct ActivityCardData {
    var type: ActivityType = .steps
    var value: Double = 0
    var goal: Double = 0
    var durationMinutes: Int = 0

    var isEmpty: Bool { value == 0 }
    var progress: Double { goal > 0 ? min(value / goal, 1.0) : 0 }

    var formattedValue: String {
        if type == .steps || value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

struct ActivityCard: View {
    var data: ActivityCardData?
    var onTap: (() -> Void)?

    var body: some View {
        AdaptiveCardRoot(content: activityContent) {
            placeholderView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .onTapGesture { onTap?() }
    }

    private var activityContent: AdaptiveCardContent? {
        guard let data, !data.isEmpty else { return nil }

        var meta: [AdaptiveCardMetaItem] = []
        if data.durationMinutes > 0 {
            meta.append(
                AdaptiveCardMetaItem(
                    systemImage: "timer",
                    text: localizedString("activity.duration", default: "%d min", arguments: [data.durationMinutes])
                )
            )
        }
        if data.goal > 0 {
            meta.append(
                AdaptiveCardMetaItem(
                    systemImage: "target",
                    text: localizedString("activity.goal_progress", default: "%d%% goal", arguments: [Int(data.progress * 100)]),
                    tint: data.type.color
                )
            )
        }

        return AdaptiveCardContent(
            preferredLayout: .metricFocus,
            accent: data.type.color,
            visual: .symbol(data.type.sfSymbol, tint: data.type.color, renderingMode: .palette),
            title: data.type.label,
            subtitle: data.durationMinutes > 0 ? localizedString("activity.duration", default: "%d min", arguments: [data.durationMinutes]) : nil,
            metric: AdaptiveCardMetric(
                value: data.formattedValue,
                unit: data.type.defaultUnit,
                caption: data.goal > 0 ? localizedString("activity.goal", default: "Goal") : nil
            ),
            progress: data.goal > 0 ? AdaptiveCardProgress(
                value: data.progress,
                label: localizedString("activity.goal", default: "Goal"),
                trailingText: "\(Int(data.progress * 100))%"
            ) : nil,
            metaItems: meta
        )
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.walk")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.4))
            Text(localizedString("activity.placeholder", default: "Tap to add an activity"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
