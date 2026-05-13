import SwiftUI

struct SignedInOnboardingView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(AuthSessionManager.self) private var authSession
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.96, blue: 0.90),
                    Color(red: 0.87, green: 0.92, blue: 0.98),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Spacer()

                Text(localization.string("signed_onboarding.title", default: "One last step before you enter Sprout"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text(localization.string("signed_onboarding.subtitle", default: "Your account is ready. Finish onboarding to unlock your private journal space and keep future AI reflections attached to you."))
                    .font(.body)
                    .foregroundStyle(.secondary)

                if let errorMessage = authSession.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.red)
                }

                Spacer()

                Button {
                    isSubmitting = true
                    Task {
                        await authSession.completeOnboarding()
                        isSubmitting = false
                    }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                        }
                        Text(localization.string("signed_onboarding.cta", default: "Finish Setup"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting)
            }
            .padding(24)
        }
    }
}
