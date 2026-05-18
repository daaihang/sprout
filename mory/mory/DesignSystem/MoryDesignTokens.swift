import SwiftUI

enum MorySpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
}

enum MoryCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
}

enum MoryCardTone {
    case neutral
    case memory
    case storyline
    case reflection
    case entity
    case warning

    var background: Color {
        switch self {
        case .neutral: return Color(.secondarySystemGroupedBackground)
        case .memory: return Color(red: 0.94, green: 0.97, blue: 1.0)
        case .storyline: return Color(red: 0.97, green: 0.95, blue: 1.0)
        case .reflection: return Color(red: 0.93, green: 0.98, blue: 0.97)
        case .entity: return Color(red: 0.96, green: 0.97, blue: 0.93)
        case .warning: return Color(red: 1.0, green: 0.96, blue: 0.90)
        }
    }

    var accent: Color {
        switch self {
        case .neutral: return .secondary
        case .memory: return .blue
        case .storyline: return .purple
        case .reflection: return .teal
        case .entity: return .green
        case .warning: return .orange
        }
    }
}

struct MorySurfaceStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(MorySpacing.large)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: MoryCornerRadius.medium, style: .continuous))
    }
}

extension View {
    func morySurface() -> some View {
        modifier(MorySurfaceStyle())
    }

    func moryCard(tone: MoryCardTone = .neutral) -> some View {
        padding(MorySpacing.medium)
            .background(tone.background)
            .clipShape(RoundedRectangle(cornerRadius: MoryCornerRadius.small, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: MoryCornerRadius.small, style: .continuous)
                    .fill(tone.accent.opacity(0.75))
                    .frame(width: 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: MoryCornerRadius.small, style: .continuous)
                    .stroke(tone.accent.opacity(0.18), lineWidth: 1)
            }
    }

    func moryPill(tone: MoryCardTone = .neutral) -> some View {
        font(.caption2.weight(.semibold))
            .padding(.horizontal, MorySpacing.small)
            .padding(.vertical, MorySpacing.xSmall)
            .background(tone.accent.opacity(0.12), in: Capsule())
            .foregroundStyle(tone.accent)
            .fixedSize(horizontal: false, vertical: true)
    }
}
