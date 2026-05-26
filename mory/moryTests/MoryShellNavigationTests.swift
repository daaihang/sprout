import AVFoundation
import Photos
import Speech
import XCTest
@testable import mory

final class MoryShellNavigationTests: XCTestCase {
    func testPublicTabsIncludeSearchAsNativeTab() {
        XCTAssertEqual(MoryAppTab.publicTabs, [.today, .memories, .insights, .search])
        XCTAssertEqual(MoryAppTab.publicTabs.map(\.titleKey), ["tab.today", "tab.memories", "tab.insights", "search.nav.title"])
    }

    func testOnboardingContentIsShortSkippableAndStartsCapture() {
        XCTAssertEqual(MoryOnboardingStep.completionStorageKey, "mory.onboarding.v1.completed")
        XCTAssertEqual(MoryOnboardingStep.allCases, [.welcome, .localFirst, .quickCapture, .optionalPermissions])
        XCTAssertEqual(MoryOnboardingStep.allCases.map(\.titleKey), [
            "onboarding.welcome.title",
            "onboarding.localFirst.title",
            "onboarding.quickCapture.title",
            "onboarding.optionalPermissions.title"
        ])
        XCTAssertEqual(MoryOnboardingStep.allCases.map(\.messageKey), [
            "onboarding.welcome.message",
            "onboarding.localFirst.message",
            "onboarding.quickCapture.message",
            "onboarding.optionalPermissions.message"
        ])
    }

    func testPublicEmptyStatesUseActionableNonDebugCopy() {
        let states: [MoryPublicEmptyState] = [
            .today,
            .memories,
            .filteredMemories,
            .insights,
            .search,
            .permissionDenied,
            .processingFailed
        ]

        XCTAssertEqual(states.map(\.id), [
            .today,
            .memories,
            .filteredMemories,
            .insights,
            .search,
            .permissionDenied,
            .processingFailed
        ])
        XCTAssertTrue(states.allSatisfy(\.hasAction))
        XCTAssertTrue(states.allSatisfy { !$0.exposesDebugCopy })
        XCTAssertEqual(MoryPublicEmptyState.today.titleKey, "empty.today.title")
        XCTAssertEqual(MoryPublicEmptyState.insights.messageKey, "empty.insights.message")
        XCTAssertEqual(MoryPublicEmptyState.permissionDenied.actionKey, "empty.action.openSettings")
        XCTAssertEqual(MoryPublicEmptyState.processingFailed.actionKey, "empty.action.retry")
    }

    func testSettingsDiagnosticsRouteIsInternalOnly() {
        XCTAssertTrue(SettingsRoute.visibleRoutes(allowsDebugTools: true).contains(.diagnostics))
        XCTAssertFalse(SettingsRoute.visibleRoutes(allowsDebugTools: false).contains(.diagnostics))
    }

    func testSettingsCoreRoutesRemainAvailableWithoutDebugTools() {
        let routes = SettingsRoute.visibleRoutes(allowsDebugTools: false)

        XCTAssertTrue(routes.contains(.account))
        XCTAssertTrue(routes.contains(.permissions))
        XCTAssertTrue(routes.contains(.notifications))
        XCTAssertTrue(routes.contains(.privacy))
        XCTAssertTrue(routes.contains(.dataControls))
        XCTAssertTrue(routes.contains(.capturePreferences))
        XCTAssertTrue(routes.contains(.appearanceLanguage))
    }

    @MainActor
    func testNavigationRouteCoordinatorRoutesDeepLinksThroughSingleBoundary() {
        let coordinator = NavigationRouteCoordinator()
        let memoryID = UUID()
        let reflectionID = UUID()

        coordinator.apply(.memories(.memory(memoryID)))
        XCTAssertEqual(coordinator.selectedTab, .memories)
        XCTAssertEqual(coordinator.memoriesRoute, .memory(memoryID))

        coordinator.apply(.insights(.reflection(reflectionID)))
        XCTAssertEqual(coordinator.selectedTab, .insights)
        XCTAssertEqual(coordinator.insightsRoute, .reflection(reflectionID))

        coordinator.apply(.search)
        XCTAssertEqual(coordinator.selectedTab, .search)
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
        XCTAssertEqual(rows.first { $0.id == .weather }?.status, .diagnosticRequired)
    }
}
