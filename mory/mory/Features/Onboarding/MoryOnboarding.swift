import SwiftUI

enum MoryOnboardingStep: String, CaseIterable, Equatable, Identifiable, Sendable {
    case welcome
    case localFirst
    case quickCapture
    case optionalPermissions

    static let completionStorageKey = MoryUserDefaultsKeys.Onboarding.completedV1

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .welcome: "onboarding.welcome.title"
        case .localFirst: "onboarding.localFirst.title"
        case .quickCapture: "onboarding.quickCapture.title"
        case .optionalPermissions: "onboarding.optionalPermissions.title"
        }
    }

    var messageKey: String {
        switch self {
        case .welcome: "onboarding.welcome.message"
        case .localFirst: "onboarding.localFirst.message"
        case .quickCapture: "onboarding.quickCapture.message"
        case .optionalPermissions: "onboarding.optionalPermissions.message"
        }
    }

    var systemImage: String {
        switch self {
        case .welcome: "sparkles"
        case .localFirst: "lock.shield"
        case .quickCapture: "square.and.pencil"
        case .optionalPermissions: "hand.raised"
        }
    }
}

struct MoryOnboardingView: View {
    let onSkip: () -> Void
    let onStartFirstMemory: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedStep = MoryOnboardingStep.welcome

    private var currentIndex: Int {
        MoryOnboardingStep.allCases.firstIndex(of: selectedStep) ?? 0
    }

    private var isLastStep: Bool {
        currentIndex == MoryOnboardingStep.allCases.count - 1
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: MorySpacing.large) {
                TabView(selection: $selectedStep) {
                    ForEach(MoryOnboardingStep.allCases) { step in
                        onboardingPage(for: step)
                            .tag(step)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                HStack {
                    Button("onboarding.skip") {
                        onSkip()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        handlePrimaryAction()
                    } label: {
                        Label(
                            isLastStep ? "onboarding.startFirstMemory" : "onboarding.next",
                            systemImage: isLastStep ? "plus.circle.fill" : "chevron.right"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, MorySpacing.xLarge)
                .padding(.bottom, MorySpacing.large)
            }
            .navigationTitle("onboarding.nav.title")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func onboardingPage(for step: MoryOnboardingStep) -> some View {
        VStack(spacing: MorySpacing.large) {
            Image(systemName: step.systemImage)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: MorySpacing.medium) {
                Text(LocalizedStringKey(step.titleKey))
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(LocalizedStringKey(step.messageKey))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, MorySpacing.xLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func handlePrimaryAction() {
        guard !isLastStep else {
            onStartFirstMemory()
            return
        }

        let nextIndex = min(currentIndex + 1, MoryOnboardingStep.allCases.count - 1)
        let nextStep = MoryOnboardingStep.allCases[nextIndex]
        if reduceMotion {
            selectedStep = nextStep
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedStep = nextStep
            }
        }
    }
}
