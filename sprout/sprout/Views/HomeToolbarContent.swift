import SwiftUI

struct HomeToolbarContent: ToolbarContent {
    let dateLabel: String
    let leadingSymbolName: String
    let onMenuTap: () -> Void
    let onProfileTap: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: onMenuTap) {
                Image(systemName: leadingSymbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 34)
                    .contentTransition(.symbolEffect(.replace))
            }
            .animation(.smooth(duration: 0.22), value: leadingSymbolName)
        }

        ToolbarItem(placement: .principal) {
            Text(dateLabel)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .lineLimit(1)
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
}
