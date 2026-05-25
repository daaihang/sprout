import SwiftData
import XCTest
@testable import mory

@MainActor
final class QualityTuningLocalBatchTests: XCTestCase {
    private static let runFlagPath = "/tmp/mory-run-local-quality-batch.flag"
    private static let reportPathFlagPath = "/tmp/mory-quality-report-path.txt"

    func testLocalCoreBatchAgainstGoServer() async throws {
        guard ProcessInfo.processInfo.environment["MORY_RUN_LOCAL_QUALITY_BATCH"] == "1"
                || FileManager.default.fileExists(atPath: Self.runFlagPath) else {
            throw XCTSkip("Create \(Self.runFlagPath) to run the local Quality Tuning Core Batch.")
        }

        let flaggedReportPath = try? String(contentsOfFile: Self.reportPathFlagPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let reportPath = ProcessInfo.processInfo.environment["MORY_LOCAL_QUALITY_REPORT_PATH"]
            ?? flaggedReportPath?.nonEmpty
            ?? "/tmp/mory-quality-report-\(Self.timestamp()).txt"
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let apiClient = MoryAPIClient(configuration: MoryAPIConfiguration(baseURL: URL(string: "http://127.0.0.1:8080")!))
        let credentialStore = KeychainCredentialStore(account: "mory-quality-\(UUID().uuidString)", inMemory: true)
        let tokenProvider = MoryAuthTokenProvider(apiClient: apiClient, credentialStore: credentialStore)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: RemoteReflectionAnalysisService(
                apiClient: apiClient,
                tokenProvider: tokenProvider
            )
        )

        let ids = QualityTuningScenarioID.allCases

        var reports: [QualityTuningRunReport] = []
        for profile in QualityTuningPromptProfile.allCases {
            for id in ids {
                let report = try await repository.runQualityTuningScenario(
                    QualityTuningRunRequest(
                        scenario: QualityTuningScenario.preset(id),
                        promptProfile: profile,
                        thresholds: .defaults
                    )
                )
                reports.append(report)
            }
        }

        let failures = reports.filter { !$0.expectationPassed }
        let body = Self.exportReport(
            reports: reports,
            failures: failures,
            baseURL: apiClient.baseURL.absoluteString
        )
        try body.write(toFile: reportPath, atomically: true, encoding: .utf8)

        XCTAssertTrue(failures.isEmpty, "Quality tuning failures written to \(reportPath): \(failures.map { "\($0.promptProfile.rawValue)/\($0.scenarioTitle)" }.joined(separator: ", "))")
    }

    private static func exportReport(
        reports: [QualityTuningRunReport],
        failures: [QualityTuningRunReport],
        baseURL: String
    ) -> String {
        var lines: [String] = []
        lines.append("# Mory Quality Tuning Local Core Batch")
        lines.append("")
        lines.append("Generated at: \(Date().formatted(.iso8601))")
        lines.append("Base URL: \(baseURL)")
        lines.append("Profiles: \(QualityTuningPromptProfile.allCases.map(\.rawValue).joined(separator: ", "))")
        lines.append("Thresholds: \(QualityTuningThresholds.defaults.summary)")
        lines.append("Total reports: \(reports.count)")
        lines.append("Failures: \(failures.count)")
        lines.append("")
        lines.append("## Scenario Matrix")
        for report in reports {
            lines.append("- \(report.expectationPassed ? "PASS" : "FAIL") \(report.promptProfile.rawValue) / \(report.scenarioTitle) / \(report.expectation.rawValue) / request \(report.requestID ?? "none")")
        }
        lines.append("")
        lines.append("## Full Debug Reports")
        lines.append(reports.map(\.exportText).joined(separator: "\n\n"))
        return lines.joined(separator: "\n")
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
