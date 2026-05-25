import AppIntents
import Foundation

@available(iOS 16.0, *)
struct CaptureMemoryInMoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture Memory in Mory"
    static var description = IntentDescription("Adds text or a link to Mory's external capture handoff path.")
    static var openAppWhenRun: Bool = true

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
        let item = try ExternalCaptureInboxWriter().enqueue(request)
        ExternalCaptureComposeHandoffStore().save(.init(itemID: item.id))
        return .result(dialog: "Opening Mory.")
    }
}

@available(iOS 16.0, *)
struct MoryCaptureShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureMemoryInMoryIntent(),
            phrases: [
                "Capture in \(.applicationName)",
                "Add memory to \(.applicationName)",
                "Record this in \(.applicationName)",
                "在 \(.applicationName) 记录"
            ],
            shortTitle: "Capture Memory",
            systemImageName: "square.and.pencil"
        )
    }
}
