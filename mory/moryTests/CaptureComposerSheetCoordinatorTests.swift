import XCTest
@testable import mory

final class CaptureComposerSheetCoordinatorTests: XCTestCase {
    func testPresentAndDismissEachSheet() {
        for sheet in CaptureComposerSheet.allCases {
            var coordinator = CaptureComposerSheetCoordinator()

            coordinator.present(sheet)
            XCTAssertEqual(coordinator.activeSheet, sheet)

            coordinator.dismissSheet()
            XCTAssertNil(coordinator.activeSheet)
        }
    }

    func testJournalingRoutesToApplePickerWhenAvailable() {
        var coordinator = CaptureComposerSheetCoordinator()

        coordinator.presentJournalingImport(isApplePickerAvailable: true)

        XCTAssertTrue(coordinator.isPresentingAppleJournalingPicker)
        XCTAssertNil(coordinator.activeSheet)

        coordinator.dismissAppleJournalingPicker()
        XCTAssertFalse(coordinator.isPresentingAppleJournalingPicker)
    }

    func testJournalingRoutesToFallbackSheetWhenApplePickerUnavailable() {
        var coordinator = CaptureComposerSheetCoordinator()

        coordinator.presentJournalingImport(isApplePickerAvailable: false)

        XCTAssertFalse(coordinator.isPresentingAppleJournalingPicker)
        XCTAssertEqual(coordinator.activeSheet, .journalingFallback)
    }
}
