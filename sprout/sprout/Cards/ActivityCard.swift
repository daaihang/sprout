import SwiftUI

enum ActivityType: String, CaseIterable {
    case steps, running, cycling, workout, sleep, meditation, swimming, yoga

    var sfSymbol: String {
        switch self {
        case .steps:      return "figure.walk"
        case .running:    return "figure.run"
        case .cycling:    return "figure.outdoor.cycle"
        case .workout:    return "dumbbell.fill"
        case .sleep:      return "bed.double.fill"
        case .meditation: return "brain.head.profile"
        case .swimming:   return "figure.pool.swim"
        case .yoga:       return "figure.mind.and.body"
        }
    }

    var label: String {
        switch self {
        case .steps:      return "步数"
        case .running:    return "跑步"
        case .cycling:    return "骑行"
        case .workout:    return "力量训练"
        case .sleep:      return "睡眠"
        case .meditation: return "冥想"
        case .swimming:   return "游泳"
        case .yoga:       return "瑜伽"
        }
    }

    var defaultUnit: String {
        switch self {
        case .steps:      return "步"
        case .running:    return "km"
        case .cycling:    return "km"
        case .workout:    return "min"
        case .sleep:      return "hr"
        case .meditation: return "min"
        case .swimming:   return "m"
        case .yoga:       return "min"
        }
    }

    var color: Color {
        switch self {
        case .steps:      return .green
        case .running:    return .orange
        case .cycling:    return .blue
        case .workout:    return .red
        case .sleep:      return .purple
        case .meditation: return .teal
        case .swimming:   return .cyan
        case .yoga:       return .pink
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
    let size: CardSize
    var data: ActivityCardData?
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let data, !data.isEmpty {
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
    private func contentView(_ data: ActivityCardData) -> some View {
        if size == .w4h1 {
            HStack(spacing: 10) {
                Image(systemName: data.type.sfSymbol)
                    .font(.system(size: 20))
                    .foregroundStyle(data.type.color)
                    .frame(width: 28)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(data.formattedValue)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(data.type.defaultUnit)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if data.goal > 0 {
                    Text("\(Int(data.progress * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(data.type.color)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        } else if size == .w4h2 {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: data.type.sfSymbol)
                        .font(.system(size: 16))
                        .foregroundStyle(data.type.color)
                    Text(data.type.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if data.durationMinutes > 0 {
                        Text("\(data.durationMinutes) min")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(data.formattedValue)
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(data.type.defaultUnit)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                if data.goal > 0 {
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
            .padding(14)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: data.type.sfSymbol)
                        .font(.system(size: 20))
                        .foregroundStyle(data.type.color)
                    Text(data.type.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if data.durationMinutes > 0 {
                        Label("\(data.durationMinutes) min", systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(data.formattedValue)
                        .font(.system(size: 54, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(data.type.defaultUnit)
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .offset(y: -4)
                }
                Spacer()
                if data.goal > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("目标")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(data.progress * 100))%  \(data.formattedValue) / \(data.goal.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", data.goal) : String(format: "%.1f", data.goal)) \(data.type.defaultUnit)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(data.type.color.opacity(0.15))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(data.type.color)
                                    .frame(width: geo.size.width * data.progress, height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var placeholderView: some View {
        VStack(spacing: size == .w4h1 ? 4 : 8) {
            Image(systemName: "figure.walk")
                .font(.system(size: size == .w4h1 ? 20 : 30))
                .foregroundStyle(.secondary.opacity(0.4))
            if size != .w4h1 {
                Text("点击添加运动记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ActivityCard_4x1: View {
    var data: ActivityCardData?
    var onTap: (() -> Void)?
    var body: some View { ActivityCard(size: .w4h1, data: data, onTap: onTap) }
}

struct ActivityCard_4x2: View {
    var data: ActivityCardData?
    var onTap: (() -> Void)?
    var body: some View { ActivityCard(size: .w4h2, data: data, onTap: onTap) }
}

struct ActivityCard_4x4: View {
    var data: ActivityCardData?
    var onTap: (() -> Void)?
    var body: some View { ActivityCard(size: .w4h4, data: data, onTap: onTap) }
}

#Preview {
    VStack(spacing: 12) {
        ActivityCard_4x1(data: ActivityCardData(type: .steps, value: 8432, goal: 10000))
        ActivityCard_4x2(data: ActivityCardData(type: .running, value: 5.2, goal: 5, durationMinutes: 32))
        ActivityCard_4x4(data: ActivityCardData(type: .sleep, value: 7.5, goal: 8, durationMinutes: 450))
    }
    .frame(width: 393)
    .padding()
}
