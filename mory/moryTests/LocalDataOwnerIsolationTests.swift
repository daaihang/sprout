import Foundation
import XCTest
@testable import mory

@MainActor
final class LocalDataOwnerIsolationTests: XCTestCase {
    func testOwnerScopedSessionsDoNotShareMemoriesAcrossOwners() async throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        var ownerASession: MoryLocalDataSession? = MoryLocalDataSession(
            ownerID: "user:apple-a",
            analysisService: OwnerIsolationRecordAnalysisService(),
            scope: .owner("user:apple-a"),
            baseDirectory: baseDirectory
        )
        _ = try await ownerASession?.memoryRepository.createMemory(
            from: MemoryCaptureDraft(
                rawText: "Owner A private memory",
                artifacts: [.text(title: nil, body: "Owner A private memory")]
            )
        )
        XCTAssertEqual(try ownerASession?.memoryRepository.fetchRecentMemories(limit: nil).count, 1)
        ownerASession = nil

        let ownerBSession = MoryLocalDataSession(
            ownerID: "user:apple-b",
            analysisService: OwnerIsolationRecordAnalysisService(),
            scope: .owner("user:apple-b"),
            baseDirectory: baseDirectory
        )
        XCTAssertEqual(try ownerBSession.memoryRepository.fetchRecentMemories(limit: nil).count, 0)

        let reopenedOwnerASession = MoryLocalDataSession(
            ownerID: "user:apple-a",
            analysisService: OwnerIsolationRecordAnalysisService(),
            scope: .owner("user:apple-a"),
            baseDirectory: baseDirectory
        )
        let reopenedMemories = try reopenedOwnerASession.memoryRepository.fetchRecentMemories(limit: nil)
        XCTAssertEqual(reopenedMemories.count, 1)
        XCTAssertEqual(reopenedMemories.first?.record.rawText, "Owner A private memory")
    }

    func testLegacyStoreIsClaimedByFirstNonGuestOwnerOnly() async throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        var legacySession: MoryLocalDataSession? = MoryLocalDataSession(
            ownerID: "legacy",
            analysisService: OwnerIsolationRecordAnalysisService(),
            scope: .legacy,
            baseDirectory: baseDirectory
        )
        _ = try await legacySession?.memoryRepository.createMemory(
            from: MemoryCaptureDraft(
                rawText: "Legacy local memory",
                artifacts: [.text(title: nil, body: "Legacy local memory")]
            )
        )
        legacySession = nil

        let suiteName = "mory.localDataOwnerIsolation.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let registry = LocalDataOwnerRegistry(defaults: defaults, baseDirectory: baseDirectory)
        XCTAssertEqual(registry.scope(for: AuthCredential.guest.localDataOwnerID), .owner(AuthCredential.guest.localDataOwnerID))
        XCTAssertEqual(registry.scope(for: "user:apple-a"), .legacy)
        XCTAssertEqual(registry.scope(for: "user:apple-b"), .owner("user:apple-b"))
        XCTAssertEqual(registry.scope(for: "user:apple-a"), .legacy)
    }

    func testAuthCredentialLocalDataOwnerIDIsStableForGuestAndSignedInUsers() {
        XCTAssertEqual(AuthCredential.guest.localDataOwnerID, "guest:device")

        let localApple = AuthCredential.localApple(userID: "apple-user-1", identityToken: "token")
        XCTAssertEqual(localApple.localDataOwnerID, "user:apple-user-1")

        let serverCredential = AuthCredential(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: nil,
            userID: "apple-user-1",
            identityToken: "token"
        )
        XCTAssertEqual(serverCredential.localDataOwnerID, "user:apple-user-1")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mory-owner-isolation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct OwnerIsolationRecordAnalysisService: ReflectionAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: record.rawText,
            themes: [],
            emotionInterpretation: "",
            salienceScore: 0,
            retrievalTerms: [],
            entityMentions: [],
            candidateEdges: [],
            followUpCandidates: [],
            reflectionHint: nil,
            createdAt: record.updatedAt
        )
    }

    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        ReflectionServiceResult(
            title: "Reflection",
            body: record.rawText,
            evidenceSummary: artifacts.map(\.summary).joined(separator: "\n"),
            confidence: 0,
            sourceRecordIDs: [record.id],
            debugTrace: nil
        )
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        ReflectionServiceResult(
            title: reflection.title,
            body: reflection.body,
            evidenceSummary: reflection.evidenceSummary,
            confidence: reflection.confidence,
            sourceRecordIDs: reflection.sourceRecordIDs,
            debugTrace: nil
        )
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        nil
    }
}
