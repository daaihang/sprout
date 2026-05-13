import SwiftUI

extension EntityKind {
    var badgeLabel: String {
        switch self {
        case .person:
            return "Person"
        case .place:
            return "Place"
        case .theme:
            return "Theme"
        case .decision:
            return "Decision"
        }
    }

    var tintColor: Color {
        switch self {
        case .person:
            return .blue
        case .place:
            return .green
        case .theme:
            return .orange
        case .decision:
            return .pink
        }
    }
}

extension View {
    func detailCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.white.opacity(0.85),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct SectionLabel: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}
