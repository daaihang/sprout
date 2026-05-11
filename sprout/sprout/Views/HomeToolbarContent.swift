import SwiftUI

struct HomeToolbarContent: ToolbarContent {
    let dateLabel: String
    let displayMode: HomeDisplayMode
    let showRecordsLabel: String
    let showCardsLabel: String
    let onDateTap: () -> Void
    let onModeToggle: () -> Void
    let onProfileTap: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: onDateTap) {
                HStack(spacing: 4) {
                    Text(dateLabel)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: onModeToggle) {
                Image(systemName: displayMode == .dashboard ? "list.bullet.rectangle" : "square.grid.2x2")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
            }
            .accessibilityLabel(displayMode == .dashboard ? showRecordsLabel : showCardsLabel)

            Button(action: onProfileTap) {
                Image(systemName: "person")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }
}
