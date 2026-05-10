import SwiftUI

struct TopNavigationBar: View {
    @State private var isShowingMenu = false
    let onProfileTapped: () -> Void

    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 · EEEE"
        return formatter.string(from: Date())
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Menu {
                    Button {
                    } label: {
                        Label("看板", systemImage: "square.grid.2x2")
                    }

                    Button {
                    } label: {
                        Label("日历", systemImage: "calendar")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Today")
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
}

#Preview {
    TopNavigationBar(onProfileTapped: {})
        .background(Color.blue.opacity(0.1))
}