import Foundation

enum PlatformCaptureDiagnosticStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case ready
    case warning
    case blocked
    case manual

    var id: String { rawValue }
}

struct PlatformCaptureDiagnosticItem: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var title: String
    var status: PlatformCaptureDiagnosticStatus
    var detail: String
    var evidence: [String]

    init(
        id: String,
        title: String,
        status: PlatformCaptureDiagnosticStatus,
        detail: String,
        evidence: [String] = []
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.detail = detail
        self.evidence = evidence
    }
}

struct PlatformCaptureInboxCounts: Codable, Hashable, Sendable {
    var pending: Int
    var imported: Int
    var dismissed: Int
    var failed: Int

    var total: Int {
        pending + imported + dismissed + failed
    }
}

struct PlatformCaptureDiagnosticsSummary: Codable, Hashable, Sendable {
    var ready: Int
    var warning: Int
    var blocked: Int
    var manual: Int
}

struct PlatformCaptureDiagnosticsSnapshot: Codable, Hashable, Sendable {
    var generatedAt: Date
    var capabilityItems: [PlatformCaptureDiagnosticItem]
    var manualValidationItems: [PlatformCaptureDiagnosticItem]
    var inboxCounts: PlatformCaptureInboxCounts
    var summary: PlatformCaptureDiagnosticsSummary

    var allItems: [PlatformCaptureDiagnosticItem] {
        capabilityItems + manualValidationItems
    }
}

@MainActor
struct PlatformCaptureDiagnosticsService {
    private let journalingAvailability: @MainActor () -> JournalingSuggestionAvailability
    private let appGroupDefaultsAvailable: @MainActor () -> Bool
    private let appGroupContainerAvailable: @MainActor () -> Bool
    private let attachmentDirectoryAvailable: @MainActor () -> Bool
    private let shareExtensionBundled: @MainActor () -> Bool
    private let appIntentsMetadataAvailable: @MainActor () -> Bool
    private let now: @MainActor () -> Date

    init(
        journalingAvailability: @escaping @MainActor () -> JournalingSuggestionAvailability = {
            JournalingSuggestionContextService().availability()
        },
        appGroupDefaultsAvailable: @escaping @MainActor () -> Bool = {
            MorySharedContainers.appGroupDefaults != nil
        },
        appGroupContainerAvailable: @escaping @MainActor () -> Bool = {
            MorySharedContainers.appGroupContainerURL != nil
        },
        attachmentDirectoryAvailable: @escaping @MainActor () -> Bool = {
            ExternalCaptureAttachmentFileStore.attachmentDirectoryURL() != nil
        },
        shareExtensionBundled: @escaping @MainActor () -> Bool = {
            guard let plugInsURL = Bundle.main.builtInPlugInsURL else { return false }
            let extensionURL = plugInsURL.appendingPathComponent("moryShareExtension.appex", isDirectory: true)
            return FileManager.default.fileExists(atPath: extensionURL.path)
        },
        appIntentsMetadataAvailable: @escaping @MainActor () -> Bool = {
            if let metadataURL = Bundle.main.url(forResource: "Metadata", withExtension: "appintents") {
                return FileManager.default.fileExists(atPath: metadataURL.path)
            }
            let generatedMetadataURL = Bundle.main.bundleURL.appendingPathComponent("Metadata.appintents", isDirectory: true)
            return FileManager.default.fileExists(atPath: generatedMetadataURL.path)
        },
        now: @escaping @MainActor () -> Date = { .now }
    ) {
        self.journalingAvailability = journalingAvailability
        self.appGroupDefaultsAvailable = appGroupDefaultsAvailable
        self.appGroupContainerAvailable = appGroupContainerAvailable
        self.attachmentDirectoryAvailable = attachmentDirectoryAvailable
        self.shareExtensionBundled = shareExtensionBundled
        self.appIntentsMetadataAvailable = appIntentsMetadataAvailable
        self.now = now
    }

    func makeSnapshot(inboxItems: [ExternalCaptureInboxItem]) -> PlatformCaptureDiagnosticsSnapshot {
        let capabilityItems = makeCapabilityItems()
        let manualValidationItems = makeManualValidationItems()
        let allItems = capabilityItems + manualValidationItems
        return PlatformCaptureDiagnosticsSnapshot(
            generatedAt: now(),
            capabilityItems: capabilityItems,
            manualValidationItems: manualValidationItems,
            inboxCounts: makeInboxCounts(from: inboxItems),
            summary: PlatformCaptureDiagnosticsSummary(
                ready: allItems.filter { $0.status == .ready }.count,
                warning: allItems.filter { $0.status == .warning }.count,
                blocked: allItems.filter { $0.status == .blocked }.count,
                manual: allItems.filter { $0.status == .manual }.count
            )
        )
    }

    private func makeCapabilityItems() -> [PlatformCaptureDiagnosticItem] {
        let availability = journalingAvailability()
        let journalingStatus: PlatformCaptureDiagnosticStatus = {
            if availability.isAvailable { return .ready }
            switch availability.reason {
            case .missingEntitlement:
                return .blocked
            case .disabledByUser, .frameworkNotLinked, .unsupportedOS:
                return .warning
            case .available:
                return .ready
            }
        }()

        let defaultsAvailable = appGroupDefaultsAvailable()
        let containerAvailable = appGroupContainerAvailable()
        let attachmentAvailable = attachmentDirectoryAvailable()
        let shareExtensionAvailable = shareExtensionBundled()
        let intentsAvailable = appIntentsMetadataAvailable()

        return [
            PlatformCaptureDiagnosticItem(
                id: "journaling.suggestions",
                title: "Journaling Suggestions",
                status: journalingStatus,
                detail: availability.detail,
                evidence: [
                    "reason=\(availability.reason.rawValue)",
                    "available=\(availability.isAvailable)"
                ]
            ),
            PlatformCaptureDiagnosticItem(
                id: "app.group.defaults",
                title: "App Group Defaults",
                status: defaultsAvailable ? .ready : .blocked,
                detail: defaultsAvailable
                    ? "The shared defaults suite is reachable for App Intent and Share handoff."
                    : "The shared defaults suite is unavailable; external capture handoff cannot be trusted on this build.",
                evidence: ["suite=\(MorySharedContainers.appGroupIdentifier)"]
            ),
            PlatformCaptureDiagnosticItem(
                id: "app.group.container",
                title: "App Group Container",
                status: containerAvailable ? .ready : .blocked,
                detail: containerAvailable
                    ? "The shared container is reachable for imported attachments."
                    : "The shared container is unavailable; image/file handoff from Share Extension will not persist attachments.",
                evidence: ["group=\(MorySharedContainers.appGroupIdentifier)"]
            ),
            PlatformCaptureDiagnosticItem(
                id: "external.capture.attachments",
                title: "External Capture Attachments",
                status: attachmentAvailable ? .ready : .warning,
                detail: attachmentAvailable
                    ? "Attachment directory can be resolved for Share Extension images."
                    : "Attachment directory is not resolvable in this runtime; text-only handoff can still be validated.",
                evidence: ["directory=\(MorySharedContainers.externalCaptureAttachmentDirectoryName)"]
            ),
            PlatformCaptureDiagnosticItem(
                id: "share.extension.bundle",
                title: "Share Extension Bundle",
                status: shareExtensionAvailable ? .ready : .warning,
                detail: shareExtensionAvailable
                    ? "The app bundle contains moryShareExtension.appex."
                    : "The current runtime bundle does not expose moryShareExtension.appex; verify a full app install on device.",
                evidence: ["expected=moryShareExtension.appex"]
            ),
            PlatformCaptureDiagnosticItem(
                id: "app.intents.metadata",
                title: "App Intents Metadata",
                status: intentsAvailable ? .ready : .warning,
                detail: intentsAvailable
                    ? "Generated App Intents metadata is present in the bundle."
                    : "Generated App Intents metadata was not found in this runtime bundle; verify shortcut discovery on device.",
                evidence: ["expected=Metadata.appintents"]
            )
        ]
    }

    private func makeManualValidationItems() -> [PlatformCaptureDiagnosticItem] {
        [
            PlatformCaptureDiagnosticItem(
                id: "manual.journaling.picker",
                title: "Open Apple Journaling Picker On Device",
                status: .manual,
                detail: "Use the capture Journaling action on a physical device and import at least one system suggestion into a normal memory draft."
            ),
            PlatformCaptureDiagnosticItem(
                id: "manual.share.extension",
                title: "Share Sheet Handoff On Device",
                status: .manual,
                detail: "Share selected text, a URL, and an image into Mory; tap Continue in Mory and confirm the main app opens the unified memory composer with content prefilled."
            ),
            PlatformCaptureDiagnosticItem(
                id: "manual.app.shortcut",
                title: "Siri / Shortcuts Phrase Validation",
                status: .manual,
                detail: "Run the Mory capture App Shortcut phrase on device and verify the resulting request enters the external capture handoff path."
            )
        ]
    }

    private func makeInboxCounts(from items: [ExternalCaptureInboxItem]) -> PlatformCaptureInboxCounts {
        PlatformCaptureInboxCounts(
            pending: items.filter { $0.status == .pending }.count,
            imported: items.filter { $0.status == .imported }.count,
            dismissed: items.filter { $0.status == .dismissed }.count,
            failed: items.filter { $0.errorMessage?.trimmedOrNil != nil }.count
        )
    }
}
