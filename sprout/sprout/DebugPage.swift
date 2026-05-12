import SwiftUI

struct DebugPage: View {
    @Environment(AppLocalization.self) private var localization

    var body: some View {
        List {
            Section(t("common.debug.voice_test", "Voice Test")) {
                NavigationLink(destination: SpeechRecognitionPage()) {
                    Label(t("common.debug.speech_to_text", "Speech to Text"), systemImage: "mic.fill")
                }
            }

            Section(t("common.debug.card_preview", "Card Preview")) {
                NavigationLink(destination: CardCalibrationView()) {
                    Label("Card Calibration", systemImage: "slider.horizontal.3")
                }

                ForEach(DebugCardKind.allCases) { kind in
                    NavigationLink(destination: CardDebugView(kind: kind)) {
                        Label(kind.title, systemImage: kind.symbolName)
                    }
                }
            }

            Section(t("common.debug.subscription", "Subscription")) {
                NavigationLink(destination: SubscriptionDebugView()) {
                    Label(t("common.debug.subscription_test", "Subscription Status & Test"), systemImage: "creditcard")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(t("common.debug.title", "Debug"))
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}

#Preview {
    DebugPage()
}
