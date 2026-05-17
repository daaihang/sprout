import AVFoundation
import Photos
import Speech
import XCTest
@testable import mory

final class MoryShellNavigationTests: XCTestCase {
    func testPublicTabsAreExactlyTodayMemoriesAndInsights() {
        XCTAssertEqual(MoryAppTab.publicTabs, [.today, .memories, .insights])
        XCTAssertEqual(MoryAppTab.publicTabs.map(\.titleKey), ["tab.today", "tab.memories", "tab.insights"])
    }

    func testSettingsDiagnosticsRouteIsInternalOnly() {
        XCTAssertTrue(SettingsRoute.visibleRoutes(allowsDebugTools: true).contains(.diagnostics))
        XCTAssertFalse(SettingsRoute.visibleRoutes(allowsDebugTools: false).contains(.diagnostics))
    }

    func testSettingsCoreRoutesRemainAvailableWithoutDebugTools() {
        let routes = SettingsRoute.visibleRoutes(allowsDebugTools: false)

        XCTAssertTrue(routes.contains(.account))
        XCTAssertTrue(routes.contains(.permissions))
        XCTAssertTrue(routes.contains(.privacy))
        XCTAssertTrue(routes.contains(.dataControls))
        XCTAssertTrue(routes.contains(.capturePreferences))
        XCTAssertTrue(routes.contains(.appearanceLanguage))
    }

    func testDefaultUserSettingsPreferenceHasSyncReadyMetadata() {
        let preference = UserSettingsPreference.defaults

        XCTAssertEqual(preference.syncKey, UserSettingsPreference.defaultSyncKey)
        XCTAssertEqual(preference.schemaVersion, UserSettingsPreference.schemaVersion)
        XCTAssertTrue(preference.linkAutoDetectEnabled)
        XCTAssertEqual(preference.defaultContextSelection, .allAvailable)
        XCTAssertEqual(preference.appearanceMode, .system)
    }

    func testPermissionSnapshotMapsRawStatusesForSettings() {
        let rows = SettingsPermissionSnapshotBuilder.make(
            locationStatus: .authorized,
            musicStatus: .denied,
            photosStatus: .limited,
            microphoneStatus: .granted,
            speechStatus: .restricted
        )

        XCTAssertEqual(rows.first { $0.id == .location }?.status, .authorized)
        XCTAssertEqual(rows.first { $0.id == .photos }?.status, .limited)
        XCTAssertEqual(rows.first { $0.id == .microphone }?.status, .authorized)
        XCTAssertEqual(rows.first { $0.id == .speech }?.status, .restricted)
        XCTAssertEqual(rows.first { $0.id == .music }?.status, .denied)
        XCTAssertEqual(rows.first { $0.id == .weather }?.status, .authorized)
    }
}
