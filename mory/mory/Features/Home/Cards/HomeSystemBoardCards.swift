import SwiftUI

struct YesterdayPanelBoardCard: View {
    let title: String
    let subtitle: String
    let recordCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title)
                .font(.headline)
                .lineLimit(2)
            Text(verbatim: subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text(verbatim: "\(recordCount) items")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct SystemPromptBoardCard: View {
    let title: String
    let subtitle: String
    let actionTitle: String?
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).lineLimit(2)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            if let actionTitle {
                Button(actionTitle, action: onAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct ContextClusterBoardCard: View {
    let title: String
    let subtitle: String
    let recordCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).lineLimit(2)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            Text("home.board.cluster.count \(recordCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct PendingActionBoardCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).lineLimit(2)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
        }
    }
}
