import SwiftUI

struct HomeToolbarContent: ToolbarContent {
    let dateLabel: String
    let onDateTap: () -> Void
    let onProfileTap: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Button(action: onDateTap) {
                titleLabel
                    .padding(.horizontal, 14)
                    .frame(height: 38)
            }
            .buttonStyle(.plain)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onProfileTap) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 34)
            }
        }
    }

    private var titleLabel: some View {
        HStack(spacing: 6) {
            Text(dateLabel)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}
