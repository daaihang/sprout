import XCTest
@testable import mory

final class MemoryDetailProductPathPolicyTests: XCTestCase {
    func testProductionDetailPathDoesNotExposeAnalysisDebugSurfaces() {
        let policy = MemoryDetailProductPathPolicy(
            environment: AppRuntimeEnvironment(
                buildChannel: .production,
                distribution: .appStore,
                bundleIdentifier: "com.speculolabs.mory",
                version: "1.0",
                buildNumber: "1"
            )
        )

        XCTAssertFalse(policy.exposesAnalysisDebugSurfaces)
    }

    func testInternalDebugDetailPathCanExposeAnalysisDebugSurfaces() {
        let policy = MemoryDetailProductPathPolicy(
            environment: AppRuntimeEnvironment(
                buildChannel: .internalBeta,
                distribution: .debug,
                bundleIdentifier: "com.speculolabs.mory",
                version: "1.0",
                buildNumber: "1"
            )
        )

        XCTAssertTrue(policy.exposesAnalysisDebugSurfaces)
    }
}
