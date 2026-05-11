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
        Group {
            if let data, !data.isEmpty {
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

    private func contentView(_ data: ActivityCardData, metrics: CardLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.isCompactHeight ? 4 : 8) {
            HStack(spacing: 8) {
                Image(systemName: data.type.sfSymbol)
                    .font(.system(size: metrics.isCompactHeight ? 16 : 18))
                    .foregroundStyle(data.type.color)
                Text(data.type.label)
                    .font(.system(size: metrics.isCompactHeight ? 12 : 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if data.durationMinutes > 0 && !metrics.isCompactWidth {
                    Text("\(data.durationMinutes) min")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(data.formattedValue)
                    .font(.system(size: metrics.isWideWidth ? 56 : (metrics.isMediumHeight ? 38 : 26), weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(data.type.defaultUnit)
                    .font(.system(size: metrics.isWideWidth ? 18 : 14))
                    .foregroundStyle(.secondary)
                    .offset(y: -4)
            }

            if data.goal > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(localizedString("activity.goal", default: "Goal"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(data.progress * 100))%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(data.type.color)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(data.type.color.opacity(0.15))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(data.type.color)
                                .frame(width: geo.size.width * data.progress, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(metrics.isCompactHeight ? 12 : 16)
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
