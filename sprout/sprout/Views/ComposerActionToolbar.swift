import SwiftUI

struct ComposerActionToolbarItem: Identifiable {
    let id: String
    let icon: String
    let accessibilityLabel: String
    let action: () -> Void
}

struct ComposerActionToolbar: View {
    enum Style {
        case card
        case keyboard

        var spacing: CGFloat {
            switch self {
            case .card:
                2
            case .keyboard:
                18
            }
        }

        var buttonSize: CGFloat {
            40
        }
    }

    let items: [ComposerActionToolbarItem]
    var style: Style = .card

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: style.spacing) {
                ForEach(items) { item in
                    Button(action: item.action) {
                        Image(systemName: item.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .frame(width: style.buttonSize, height: style.buttonSize)
                    }
                    .accessibilityLabel(item.accessibilityLabel)
                }
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
