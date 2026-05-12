import SwiftUI

struct TopNavigationBar: View {
    @Environment(AppLocalization.self) private var localization
    let onProfileTapped: () -> Void

    private var currentDateString: String {
        localization.templateDateString(from: Date(), template: "MMMMdEEEE")
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Menu {
                    Button {
                    } label: {
                        Label(t("content.nav.dashboard", "Dashboard"), systemImage: "square.grid.2x2")
                    }

                    Button {
                    } label: {
                        Label(t("content.nav.calendar", "Calendar"), systemImage: "calendar")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(t("content.date.today", "Today"))
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                }

                Text(currentDateString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onProfileTapped) {
                Image(systemName: "person")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}

#Preview {
    TopNavigationBar(onProfileTapped: {})
        .background(Color.blue.opacity(0.1))
}
