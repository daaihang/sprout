import SwiftUI

struct DebugActionNotice: View {
    enum Kind {
        case mutating
        case destructive

        var title: String {
            switch self {
            case .mutating:
                return "Mutates local data"
            case .destructive:
                return "Destructive action"
            }
        }

        var defaultMessage: String {
            switch self {
            case .mutating:
                return "This debug action writes to the local repository or system index."
            case .destructive:
                return "This debug action can remove data or change account/session state."
            }
        }

        var symbolName: String {
            switch self {
            case .mutating:
                return "pencil.and.list.clipboard"
            case .destructive:
                return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .mutating:
                return .orange
            case .destructive:
                return .red
            }
        }
    }

    let kind: Kind
    var message: String?

    init(_ kind: Kind, message: String? = nil) {
        self.kind = kind
        self.message = message
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(.caption.weight(.semibold))
                Text(message ?? kind.defaultMessage)
                    .font(.caption2)
            }
        } icon: {
            Image(systemName: kind.symbolName)
        }
        .foregroundStyle(kind.color)
    }
}
