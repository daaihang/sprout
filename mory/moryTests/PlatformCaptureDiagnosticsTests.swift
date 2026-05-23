import XCTest
@testable import mory

@MainActor
final class PlatformCaptureDiagnosticsTests: XCTestCase {
    func testDiagnosticsSnapshotSummarizesCapabilitiesAndInboxCounts() throws {
        let service = PlatformCaptureDiagnosticsService(
            journalingAvailability: { .available },
            appGroupDefaultsAvailable: { true },
            appGroupContainerAvailable: { true },
            attachmentDirectoryAvailable: { true },
            shareExtensionBundled: { true },
            appIntentsMetadataAvailable: { true },
            now: { Date(timeIntervalSince1970: 1_800_000_100) }
        )

        let items = [
            try ExternalCaptureInboxCodec().makeItem(
                from: ExternalCaptureRequest(sourceKind: .shareSheet, title: "Pending", text: "Pending"),
                now: Date(timeIntervalSince1970: 1_800_000_001)
            ),
            ExternalCaptureInboxItem(
                payloadKind: .externalCapture,
                sourceKind: .appIntent,
                title: "Imported",
                summary: "Imported",
                payloadData: Data(),
                status: .imported,
                receivedAt: Date(timeIntervalSince1970: 1_800_000_002),
                updatedAt: Date(timeIntervalSince1970: 1_800_000_003),
                importedRecordID: UUID()
            ),
            ExternalCaptureInboxItem(
                payloadKind: .externalCapture,
                sourceKind: .shortcut,
                title: "Dismissed",
                summary: "Dismissed",
                payloadData: Data(),
                status: .dismissed,
                receivedAt: Date(timeIntervalSince1970: 1_800_000_004),
                updatedAt: Date(timeIntervalSince1970: 1_800_000_005),
                dismissedAt: Date(timeIntervalSince1970: 1_800_000_006)
            ),
            ExternalCaptureInboxItem(
                payloadKind: .externalCapture,
                sourceKind: .shareSheet,
                title: "Failed",
                summary: "Failed",
                payloadData: Data(),
                status: .pending,
                receivedAt: Date(timeIntervalSince1970: 1_800_000_007),
                updatedAt: Date(timeIntervalSince1970: 1_800_000_008),
                errorMessage: "decode failed"
            )
        ]

        let snapshot = service.makeSnapshot(inboxItems: items)

        XCTAssertEqual(snapshot.generatedAt, Date(timeIntervalSince1970: 1_800_000_100))
        XCTAssertEqual(snapshot.capabilityItems.count, 6)
        XCTAssertEqual(snapshot.manualValidationItems.count, 3)
        XCTAssertEqual(snapshot.inboxCounts.pending, 2)
        XCTAssertEqual(snapshot.inboxCounts.imported, 1)
        XCTAssertEqual(snapshot.inboxCounts.dismissed, 1)
        XCTAssertEqual(snapshot.inboxCounts.failed, 1)
        XCTAssertEqual(snapshot.summary.ready, 6)
        XCTAssertEqual(snapshot.summary.manual, 3)
        XCTAssertEqual(snapshot.summary.warning, 0)
        XCTAssertEqual(snapshot.summary.blocked, 0)
    }

    func testDiagnosticsFlagsMissingEntitlementAndAppGroupAsBlocked() {
        let service = PlatformCaptureDiagnosticsService(
            journalingAvailability: {
                JournalingSuggestionAvailability(
                    isAvailable: false,
                    reason: .missingEntitlement,
                    detail: "Missing entitlement."
                )
            },
            appGroupDefaultsAvailable: { false },
            appGroupContainerAvailable: { false },
            attachmentDirectoryAvailable: { false },
            shareExtensionBundled: { false },
            appIntentsMetadataAvailable: { false },
            now: { Date(timeIntervalSince1970: 1_800_000_200) }
        )

        let snapshot = service.makeSnapshot(inboxItems: [])
        let statuses = Dictionary(uniqueKeysWithValues: snapshot.capabilityItems.map { ($0.id, $0.status) })

        XCTAssertEqual(statuses["journaling.suggestions"], .blocked)
        XCTAssertEqual(statuses["app.group.defaults"], .blocked)
        XCTAssertEqual(statuses["app.group.container"], .blocked)
        XCTAssertEqual(statuses["external.capture.attachments"], .warning)
        XCTAssertEqual(statuses["share.extension.bundle"], .warning)
        XCTAssertEqual(statuses["app.intents.metadata"], .warning)
        XCTAssertEqual(snapshot.summary.blocked, 3)
        XCTAssertEqual(snapshot.summary.warning, 3)
        XCTAssertEqual(snapshot.summary.manual, 3)
    }

    func testDiagnosticsKeepsDeviceOnlyChecksManual() {
        let service = PlatformCaptureDiagnosticsService(
            journalingAvailability: { .available },
            appGroupDefaultsAvailable: { true },
            appGroupContainerAvailable: { true },
            attachmentDirectoryAvailable: { true },
            shareExtensionBundled: { true },
            appIntentsMetadataAvailable: { true }
        )

        let snapshot = service.makeSnapshot(inboxItems: [])

        XCTAssertEqual(snapshot.manualValidationItems.map(\.status), [.manual, .manual, .manual])
        XCTAssertEqual(
            snapshot.manualValidationItems.map(\.id),
            ["manual.journaling.picker", "manual.share.extension", "manual.app.shortcut"]
        )
    }
}
