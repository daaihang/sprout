import SwiftUI

struct WelcomeView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(InstallExperienceStore.self) private var installExperience

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.89, blue: 0.80),
                    Color(red: 0.87, green: 0.93, blue: 0.88),
                    Color(red: 0.81, green: 0.89, blue: 0.97),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "tree.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color(red: 0.16, green: 0.42, blue: 0.31))
                    .padding(22)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                Text(localization.string("welcome.title", default: "Memories become clearer when they are gently revisited."))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(localization.string("welcome.subtitle", default: "Start with a quick guided reflection. You can try the AI experience first and sign in when you are ready to keep going."))
                    .font(.system(size: 17, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)

                Spacer()

                Button(localization.string("welcome.cta", default: "Start Exploring")) {
                    installExperience.markWelcomeSeen()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}
