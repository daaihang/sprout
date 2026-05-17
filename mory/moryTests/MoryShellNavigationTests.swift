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
        XCTAssertTrue(routes.contains(.capturePreferences))
        XCTAssertTrue(routes.contains(.appearanceLanguage))
    }
}
