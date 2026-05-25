import SwiftData
import XCTest
@testable import mory

@MainActor
final class RemotePushSyncServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PushDeviceRegistrationStore.resetForTests()
        RemotePushSyncURLProtocol.responseHandler = nil
    }

    override func tearDown() {
        RemotePushSyncURLProtocol.responseHandler = nil
        PushDeviceRegistrationStore.resetForTests()
        super.tearDown()
    }

    func testSyncRegistrationSendsExpandedPreferencePayload() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_500_000)
        try configurePreferences(on: repository, now: now)
        try repository.upsertClarificationQuestion(
            ClarificationQuestion(
                kind: .dailyReflection,
                prompt: "What mattered most today?",
                targetType: .record,
                targetID: UUID(),
                priority: 0.8,
                reason: "Ready for remote delivery.",
                createdAt: now
            )
        )
        PushDeviceRegistrationStore.saveAPNSToken(Data([0xAA, 0xBB, 0xCC]))

        let expectation = expectation(description: "push register called")
        var capturedPayload: MoryAPIClient.PushRegisterPayload?
        RemotePushSyncURLProtocol.responseHandler = { request in
            if request.url?.path == "/api/push/register" {
                capturedPayload = try JSONDecoder().decode(
                    PushRegisterRequestBody.self,
                    from: XCTUnwrap(Self.requestBodyData(from: request))
                ).asClientPayload()
                expectation.fulfill()
                return Self.jsonResponse(
                    request: request,
                    statusCode: 200,
                    body: #"{"registered":true,"user_id":"guest"}"#
                )
            }
            return Self.jsonResponse(
                request: request,
                statusCode: 500,
                body: #"{"error":"unexpected path"}"#
            )
        }

        let service = try await makeService()
        await service.syncRegistrationIfPossible(repository: repository, force: true)
        await fulfillment(of: [expectation], timeout: 2)

        let payload = try XCTUnwrap(capturedPayload)
        XCTAssertFalse(payload.apnsToken.isEmpty)
        XCTAssertTrue(payload.hasQuestionReady)
        XCTAssertTrue(payload.notificationsEnabled)
        XCTAssertTrue(payload.analysisReadyEnabled)
        XCTAssertTrue(payload.dailyQuestionEnabled)
        XCTAssertTrue(payload.reflectionReadyEnabled)
        XCTAssertEqual(payload.deliveryPace, NotificationFrequencyStrategy.active.rawValue)
        XCTAssertEqual(payload.maxPerDay, 4)
        XCTAssertEqual(payload.minimumMinutesBetweenNotifications, 30)
        XCTAssertEqual(payload.quietStart, "23:15")
        XCTAssertEqual(payload.quietEnd, "07:45")
        XCTAssertTrue(payload.richPreviewsEnabled)
        XCTAssertTrue(payload.localIntelligenceEnabled)
        XCTAssertTrue(payload.cloudIntelligenceEnabled)
        XCTAssertTrue(payload.semanticSearchEnabled)
        XCTAssertTrue(payload.homeSuggestionsEnabled)
    }

    func testFailedWritebackIsRetriedAfterSuccessfulSync() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_500_100)
        try configurePreferences(on: repository, now: now)
        PushDeviceRegistrationStore.saveAPNSToken(Data([0x01, 0x02, 0x03]))

        var writebackAttempts = 0
        RemotePushSyncURLProtocol.responseHandler = { request in
            switch request.url?.path {
            case "/api/push/delivery-writeback":
                writebackAttempts += 1
                if writebackAttempts == 1 {
                    return Self.jsonResponse(
                        request: request,
                        statusCode: 500,
                        body: #"{"error":"temporary failure"}"#
                    )
                }
                return Self.jsonResponse(
                    request: request,
                    statusCode: 200,
                    body: #"{"accepted":true,"user_id":"guest"}"#
                )
            case "/api/push/register":
                return Self.jsonResponse(
                    request: request,
                    statusCode: 200,
                    body: #"{"registered":true,"user_id":"guest"}"#
                )
            default:
                return Self.jsonResponse(
                    request: request,
                    statusCode: 500,
                    body: #"{"error":"unexpected path"}"#
                )
            }
        }

        let service = try await makeService()
        let event = NotificationInteractionEvent(
            action: .opened,
            payload: LocalNotificationPayload(
                intentID: UUID(),
                kind: .dailyQuestion,
                targetType: .question,
                targetID: UUID()
            ),
            receivedAt: now
        )

        await service.writeBackInteraction(event)
        XCTAssertEqual(writebackAttempts, 1)
        XCTAssertEqual(PushDeviceRegistrationStore.pendingWritebackCountForTests(), 1)

        await service.syncRegistrationIfPossible(repository: repository, force: true)

        XCTAssertEqual(writebackAttempts, 2)
        XCTAssertEqual(PushDeviceRegistrationStore.pendingWritebackCountForTests(), 0)
    }

    func testRegistrationDigestAndWritebackRetryQueueAreOwnerScoped() {
        PushDeviceRegistrationStore.configureOwnerForTests("user:owner-a")
        PushDeviceRegistrationStore.saveLastRegistrationDigest("digest-a")
        PushDeviceRegistrationStore.enqueuePendingWriteback(makeWritebackPayload(intentID: "intent-a"))
        XCTAssertEqual(PushDeviceRegistrationStore.lastRegistrationDigest(), "digest-a")
        XCTAssertEqual(PushDeviceRegistrationStore.pendingWritebackCountForTests(), 1)

        PushDeviceRegistrationStore.configureOwnerForTests("user:owner-b")
        XCTAssertNil(PushDeviceRegistrationStore.lastRegistrationDigest())
        XCTAssertEqual(PushDeviceRegistrationStore.pendingWritebackCountForTests(), 0)
        PushDeviceRegistrationStore.saveLastRegistrationDigest("digest-b")
        PushDeviceRegistrationStore.enqueuePendingWriteback(makeWritebackPayload(intentID: "intent-b"))

        PushDeviceRegistrationStore.configureOwnerForTests("user:owner-a")
        XCTAssertEqual(PushDeviceRegistrationStore.lastRegistrationDigest(), "digest-a")
        XCTAssertEqual(PushDeviceRegistrationStore.pendingWritebackCountForTests(), 1)

        PushDeviceRegistrationStore.configureOwnerForTests("user:owner-b")
        XCTAssertEqual(PushDeviceRegistrationStore.lastRegistrationDigest(), "digest-b")
        XCTAssertEqual(PushDeviceRegistrationStore.pendingWritebackCountForTests(), 1)
    }

    func testEnqueueRemoteIntentSendsProductionTargetPayload() async throws {
        let targetID = UUID()
        let intentID = UUID()
        let scheduledAt = Date(timeIntervalSince1970: 1_800_500_200)
        let intent = NotificationIntent(
            id: intentID,
            kind: .analysisReady,
            title: "Mory",
            body: "A decision pattern is ready.",
            privacyLevel: .contextual,
            targetType: .decision,
            targetID: targetID,
            scheduledAt: scheduledAt,
            deliveryChannel: .remote
        )

        let expectation = expectation(description: "push enqueue called")
        var requestJSON: [String: Any]?
        RemotePushSyncURLProtocol.responseHandler = { request in
            if request.url?.path == "/api/push/enqueue" {
                let data = try XCTUnwrap(Self.requestBodyData(from: request))
                requestJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                expectation.fulfill()
                return Self.jsonResponse(
                    request: request,
                    statusCode: 200,
                    body: #"{"accepted":true,"user_id":"guest","queued_count":1,"skipped_count":0,"sent_count":0,"failed_count":0}"#
                )
            }
            return Self.jsonResponse(
                request: request,
                statusCode: 500,
                body: #"{"error":"unexpected path"}"#
            )
        }

        let service = try await makeService()
        let response = try await service.enqueueRemoteNotificationIntent(intent)
        await fulfillment(of: [expectation], timeout: 2)

        XCTAssertEqual(response.queuedCount, 1)
        let json = try XCTUnwrap(requestJSON)
        XCTAssertEqual(json["target_type"] as? String, "decision")
        XCTAssertEqual(json["target_id"] as? String, targetID.uuidString)
        XCTAssertEqual(json["privacy_level"] as? String, "contextual")

        let target = try XCTUnwrap(json["target"] as? [String: Any])
        XCTAssertEqual(target["type"] as? String, "decision")
        XCTAssertEqual(target["id"] as? String, targetID.uuidString)
        XCTAssertEqual(target["entity_kind"] as? String, "decision")

        let payload = try XCTUnwrap(json["payload"] as? [String: Any])
        XCTAssertEqual(payload["intent_id"] as? String, intentID.uuidString)
        XCTAssertEqual(payload["delivery_channel"] as? String, "remote")
        XCTAssertEqual((payload["target"] as? [String: Any])?["type"] as? String, "decision")
    }

    private func makeRepositoryFixture() -> RemotePushRepositoryFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: RemotePushTestAnalysisService()
        )
        return RemotePushRepositoryFixture(container: container, repository: repository)
    }

    private func makeService() async throws -> RemotePushSyncService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RemotePushSyncURLProtocol.self]
        let apiClient = MoryAPIClient(
            configuration: MoryAPIConfiguration(baseURL: URL(string: "https://push.test")!),
            session: URLSession(configuration: configuration)
        )
        let credentialStore = KeychainCredentialStore(inMemory: true)
        try await credentialStore.saveCredential(.guest)
        let tokenProvider = MoryAuthTokenProvider(
            apiClient: apiClient,
            credentialStore: credentialStore
        )
        return RemotePushSyncService(apiClient: apiClient, tokenProvider: tokenProvider)
    }

    private func makeWritebackPayload(intentID: String) -> MoryAPIClient.PushDeliveryWritebackPayload {
        MoryAPIClient.PushDeliveryWritebackPayload(
            deviceID: "device",
            intentID: intentID,
            action: "opened",
            kind: "debugTest",
            targetType: "question",
            targetID: UUID().uuidString,
            occurredAt: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_800_500_000))
        )
    }

    private func configurePreferences(
        on repository: MoryMemoryRepository,
        now: Date
    ) throws {
        var preferences = IntelligencePreferences.defaults
        preferences.localIntelligenceEnabled = true
        preferences.cloudIntelligenceEnabled = true
        preferences.homeSuggestionsEnabled = true
        preferences.notificationPreferences = NotificationPreferences(
            enabled: true,
            analysisReadyEnabled: true,
            dailyQuestionEnabled: true,
            reflectionReadyEnabled: true,
            frequencyStrategy: .active,
            maxPerDay: 4,
            minimumMinutesBetweenNotifications: 30,
            quietHoursStartHour: 23,
            quietHoursStartMinute: 15,
            quietHoursEndHour: 7,
            quietHoursEndMinute: 45,
            richPreviewsEnabled: true
        )
        preferences.updatedAt = now
        try repository.saveIntelligencePreferences(preferences)

        var flags = V6FeatureFlags.defaults
        flags.semanticSearch = true
        flags.updatedAt = now
        try repository.saveV6FeatureFlags(flags)
    }

    private static func jsonResponse(
        request: URLRequest,
        statusCode: Int,
        body: String
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }

    private static func requestBodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read < 0 {
                return nil
            }
            if read == 0 {
                break
            }
            data.append(buffer, count: read)
        }
        return data
    }
}

private struct RemotePushRepositoryFixture {
    let container: ModelContainer
    let repository: MoryMemoryRepository
}

private struct PushRegisterRequestBody: Decodable {
    let deviceID: String
    let apnsToken: String
    let timezone: String
    let hasQuestionReady: Bool
    let notificationsEnabled: Bool
    let analysisReadyEnabled: Bool
    let dailyQuestionEnabled: Bool
    let reflectionReadyEnabled: Bool
    let deliveryPace: String
    let maxPerDay: Int
    let minimumMinutesBetweenNotifications: Int
    let quietStart: String?
    let quietEnd: String?
    let richPreviewsEnabled: Bool
    let localIntelligenceEnabled: Bool
    let cloudIntelligenceEnabled: Bool
    let semanticSearchEnabled: Bool
    let homeSuggestionsEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case apnsToken = "apns_token"
        case timezone
        case hasQuestionReady = "has_question_ready"
        case notificationsEnabled = "notifications_enabled"
        case analysisReadyEnabled = "analysis_ready_enabled"
        case dailyQuestionEnabled = "daily_question_enabled"
        case reflectionReadyEnabled = "reflection_ready_enabled"
        case deliveryPace = "delivery_pace"
        case maxPerDay = "max_per_day"
        case minimumMinutesBetweenNotifications = "minimum_minutes_between_notifications"
        case quietStart = "quiet_start"
        case quietEnd = "quiet_end"
        case richPreviewsEnabled = "rich_previews_enabled"
        case localIntelligenceEnabled = "local_intelligence_enabled"
        case cloudIntelligenceEnabled = "cloud_intelligence_enabled"
        case semanticSearchEnabled = "semantic_search_enabled"
        case homeSuggestionsEnabled = "home_suggestions_enabled"
    }

    func asClientPayload() -> MoryAPIClient.PushRegisterPayload {
        .init(
            deviceID: deviceID,
            apnsToken: apnsToken,
            timezone: timezone,
            hasQuestionReady: hasQuestionReady,
            notificationsEnabled: notificationsEnabled,
            analysisReadyEnabled: analysisReadyEnabled,
            dailyQuestionEnabled: dailyQuestionEnabled,
            reflectionReadyEnabled: reflectionReadyEnabled,
            deliveryPace: deliveryPace,
            maxPerDay: maxPerDay,
            minimumMinutesBetweenNotifications: minimumMinutesBetweenNotifications,
            quietStart: quietStart,
            quietEnd: quietEnd,
            richPreviewsEnabled: richPreviewsEnabled,
            localIntelligenceEnabled: localIntelligenceEnabled,
            cloudIntelligenceEnabled: cloudIntelligenceEnabled,
            semanticSearchEnabled: semanticSearchEnabled,
            homeSuggestionsEnabled: homeSuggestionsEnabled
        )
    }
}

private struct RemotePushTestAnalysisService: RecordAnalysisServing {
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
            salienceScore: 0.4,
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
        throw RemotePushTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw RemotePushTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        nil
    }
}

private enum RemotePushTestError: Error {
    case unsupported
}

private final class RemotePushSyncURLProtocol: URLProtocol {
    static var responseHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let responseHandler = Self.responseHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try responseHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
