import AppIntents
import Foundation

@available(iOS 16.0, *)
struct CaptureMemoryInMoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture Memory in Mory"
    static var description = IntentDescription("Adds text or a link to Mory's external capture inbox.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Text")
    var text: String

    @Parameter(title: "Title")
    var titleText: String?

    @Parameter(title: "URL")
    var url: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let request = ExternalCaptureRequest(
            sourceKind: .appIntent,
            title: titleText?.trimmedOrNil,
            text: text.trimmedOrNil ?? "Captured from App Intent.",
            url: url?.trimmedOrNil,
            context: "appIntent:CaptureMemoryInMoryIntent"
        )
        _ = try ExternalCaptureInboxWriter().enqueue(request)
        return .result(dialog: "Added to Mory inbox.")
    }
}

@available(iOS 16.0, *)
struct MoryCaptureShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureMemoryInMoryIntent(),
            phrases: [
                "Capture in \(.applicationName)",
                "Add memory to \(.applicationName)"
            ],
            shortTitle: "Capture Memory",
            systemImageName: "square.and.pencil"
        )
    }
}
