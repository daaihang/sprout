import SwiftUI

struct HomeScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Mory")
                    .font(.largeTitle.weight(.bold))

                Text("Phase 1 app shell is in place. The next steps will land the formal Domain, SwiftData persistence, and the first memory workflow on top of this structure.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Label("App shell assembled", systemImage: "checkmark.circle.fill")
                    Label("Template SwiftData sample removed", systemImage: "checkmark.circle.fill")
                    Label("Top-level architecture folders created", systemImage: "checkmark.circle.fill")
                }
                .font(.subheadline.weight(.medium))

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .navigationTitle("Home")
    }
}

#Preview {
    NavigationStack {
        HomeScreen()
    }
}
