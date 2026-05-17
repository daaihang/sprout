import Foundation

actor MoryAuthTokenProvider {
    private let apiClient: MoryAPIClient
    private let credentialStore: KeychainCredentialStore
    private var cachedToken: String?
    private var tokenExpiresAt: Date?
    private let refreshMarginSeconds: TimeInterval = 60

    init(apiClient: MoryAPIClient, credentialStore: KeychainCredentialStore) {
        self.apiClient = apiClient
        self.credentialStore = credentialStore
    }

    func accessToken() async throws -> String {
        if let cachedToken, let tokenExpiresAt, tokenExpiresAt > Date().addingTimeInterval(refreshMarginSeconds) {
            return cachedToken
        }

        if let credential = await credentialStore.loadCredential() {
            if credential.isGuest {
                return credential.accessToken
            }

            if !credential.accessToken.isEmpty,
               let expiresAt = credential.expiresAt,
               expiresAt > Date().addingTimeInterval(refreshMarginSeconds) {
                cachedToken = credential.accessToken
                tokenExpiresAt = expiresAt
                return credential.accessToken
            }

            if !credential.refreshToken.isEmpty {
                let auth = try await apiClient.refreshToken(refreshToken: credential.refreshToken)
                let refreshedCredential = AuthCredential(
                    accessToken: auth.accessToken,
                    refreshToken: auth.refreshToken ?? credential.refreshToken,
                    expiresAt: parseExpiresAt(auth.expiresAt),
                    userID: auth.user.id,
                    identityToken: credential.identityToken
                )
                try await credentialStore.saveCredential(refreshedCredential)
                cachedToken = refreshedCredential.accessToken
                tokenExpiresAt = refreshedCredential.expiresAt
                return refreshedCredential.accessToken
            }
        }

        let identityToken: String
        #if DEBUG
        identityToken = (try? await credentialStore.getIdentityToken()) ?? "dev-user"
        #else
        identityToken = try await credentialStore.getIdentityToken() ?? {
            throw AuthTokenError.noIdentityToken
        }()
        #endif

        let auth = try await apiClient.authenticate(identityToken: identityToken)
        let credential = AuthCredential(
            accessToken: auth.accessToken,
            refreshToken: auth.refreshToken ?? auth.accessToken,
            expiresAt: parseExpiresAt(auth.expiresAt),
            userID: auth.user.id,
            identityToken: identityToken
        )
        try await credentialStore.saveCredential(credential)
        cachedToken = credential.accessToken
        tokenExpiresAt = credential.expiresAt
        return credential.accessToken
    }

    func invalidate() {
        cachedToken = nil
        tokenExpiresAt = nil
    }

    private func parseExpiresAt(_ expiresAt: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: expiresAt)
            ?? ISO8601DateFormatter().date(from: expiresAt)
    }

    enum AuthTokenError: Error, LocalizedError {
        case noIdentityToken

        var errorDescription: String? {
            switch self {
            case .noIdentityToken:
                return "No identity token available. Please sign in with Apple."
            }
        }
    }
}

struct RemoteRecordAnalysisService: RecordAnalysisServing {
    private actor DebugTraceStore {
        private var latest: DebugPipelineTraceSnapshot?

        func set(_ value: DebugPipelineTraceSnapshot?) {
            latest = value
        }

        func get() -> DebugPipelineTraceSnapshot? {
            latest
        }
    }

    private let requestBuilder = AnalyzeRequestBuilder()
    private let responseMapper = AnalyzeResponseMapper()
    private let apiClient: MoryAPIClient
    private let tokenProvider: MoryAuthTokenProvider
    private let debugTraceStore = DebugTraceStore()

    init(
        apiClient: MoryAPIClient,
        tokenProvider: MoryAuthTokenProvider
    ) {
        self.apiClient = apiClient
        self.tokenProvider = tokenProvider
    }

    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference] = []
    ) async throws -> RecordAnalysisSnapshot {
        let request = requestBuilder.build(
            record: record,
            artifacts: artifacts,
            knownEntities: knownEntities,
            analysisReason: "capture_ingest"
        )
        let requestBody = String(data: (try? JSONEncoder().encode(request)) ?? Data(), encoding: .utf8)

        do {
            let token = try await tokenProvider.accessToken()
            let response = try await apiClient.analyzeRecords(payload: request, bearerToken: token)
            let responseBody = String(data: (try? JSONEncoder().encode(response)) ?? Data(), encoding: .utf8)
            await debugTraceStore.set(
                DebugPipelineTraceSnapshot(
                    requestID: await apiClient.latestDebugRequestID(),
                    requestBody: requestBody,
                    responseBody: responseBody,
                    rawErrorBody: nil,
                    statusCode: nil,
                    failedStage: nil
                )
            )
            return responseMapper.map(recordID: record.id, response: response, createdAt: record.updatedAt)
        } catch MoryAPIClient.APIError.unauthorized {
            await tokenProvider.invalidate()
            let token = try await tokenProvider.accessToken()
            let response = try await apiClient.analyzeRecords(payload: request, bearerToken: token)
            let responseBody = String(data: (try? JSONEncoder().encode(response)) ?? Data(), encoding: .utf8)
            await debugTraceStore.set(
                DebugPipelineTraceSnapshot(
                    requestID: await apiClient.latestDebugRequestID(),
                    requestBody: requestBody,
                    responseBody: responseBody,
                    rawErrorBody: nil,
                    statusCode: nil,
                    failedStage: nil
                )
            )
            return responseMapper.map(recordID: record.id, response: response, createdAt: record.updatedAt)
        } catch {
            let apiTrace = await apiClient.latestDebugError()
            let requestID: String?
            if let traceRequestID = apiTrace?.requestID {
                requestID = traceRequestID
            } else {
                requestID = await apiClient.latestDebugRequestID()
            }
            await debugTraceStore.set(
                DebugPipelineTraceSnapshot(
                    requestID: requestID,
                    requestBody: requestBody,
                    responseBody: apiTrace?.responseBody,
                    rawErrorBody: apiTrace?.rawErrorBody,
                    statusCode: apiTrace?.statusCode,
                    failedStage: apiTrace?.failedStage
                )
            )
            throw error
        }
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        await debugTraceStore.get()
    }

    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference] = [],
        prompt: String? = nil
    ) async throws -> ReflectionServiceResult {
        let payload = makeReflectionPayload(
            record: record,
            artifacts: artifacts,
            linkedArcID: linkedArcID,
            knownEntities: knownEntities,
            prompt: prompt
        )
        return try await sendReflection(payload: payload, mode: .generate)
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference] = [],
        prompt: String? = nil
    ) async throws -> ReflectionServiceResult {
        let replayRecord = record ?? RecordShell(
            createdAt: reflection.createdAt,
            updatedAt: reflection.createdAt,
            captureSource: .manual,
            rawText: reflection.body,
            inputContext: "reflection replay"
        )
        let replayPrompt = prompt?.trimmedOrNil ?? reflection.body.trimmedOrNil ?? linkedArc?.summary ?? replayRecord.rawText
        let payload = makeReflectionPayload(
            record: replayRecord,
            artifacts: artifacts,
            linkedArcID: linkedArc?.id ?? reflection.linkedTemporalArcID,
            knownEntities: knownEntities,
            prompt: replayPrompt
        )
        return try await sendReflection(payload: payload, mode: .replay)
    }

    private enum ReflectionMode {
        case generate
        case replay
    }

    private func sendReflection(
        payload: MoryAPIClient.ReflectionPayload,
        mode: ReflectionMode
    ) async throws -> ReflectionServiceResult {
        let requestBody = String(data: (try? JSONEncoder().encode(payload)) ?? Data(), encoding: .utf8)

        do {
            let token = try await tokenProvider.accessToken()
            let response = switch mode {
            case .generate:
                try await apiClient.generateReflection(payload: payload, bearerToken: token)
            case .replay:
                try await apiClient.replayReflection(payload: payload, bearerToken: token)
            }
            return try await persistReflectionSuccess(response: response, requestBody: requestBody)
        } catch MoryAPIClient.APIError.unauthorized {
            await tokenProvider.invalidate()
            let token = try await tokenProvider.accessToken()
            let response = switch mode {
            case .generate:
                try await apiClient.generateReflection(payload: payload, bearerToken: token)
            case .replay:
                try await apiClient.replayReflection(payload: payload, bearerToken: token)
            }
            return try await persistReflectionSuccess(response: response, requestBody: requestBody)
        } catch {
            let apiTrace = await apiClient.latestDebugError()
            let requestID: String?
            if let traceRequestID = apiTrace?.requestID {
                requestID = traceRequestID
            } else {
                requestID = await apiClient.latestDebugRequestID()
            }
            let trace = DebugPipelineTraceSnapshot(
                requestID: requestID,
                requestBody: requestBody,
                responseBody: apiTrace?.responseBody,
                rawErrorBody: apiTrace?.rawErrorBody,
                statusCode: apiTrace?.statusCode,
                failedStage: apiTrace?.failedStage
            )
            await debugTraceStore.set(trace)
            throw error
        }
    }

    private func persistReflectionSuccess(
        response: MoryAPIClient.ReflectionResponse,
        requestBody: String?
    ) async throws -> ReflectionServiceResult {
        struct ReflectionDebugResponseBody: Encodable {
            let title: String
            let body: String
            let evidenceSummary: String
            let confidence: Double
            let sourceRecordIDs: [String]

            enum CodingKeys: String, CodingKey {
                case title
                case body
                case evidenceSummary = "evidence_summary"
                case confidence
                case sourceRecordIDs = "source_record_ids"
            }
        }
        let responseBody = String(
            data: try JSONEncoder().encode(
                ReflectionDebugResponseBody(
                    title: response.title,
                    body: response.body,
                    evidenceSummary: response.evidenceSummary,
                    confidence: response.confidence,
                    sourceRecordIDs: response.sourceRecordIDs
                )
            ),
            encoding: .utf8
        )
        let trace = DebugPipelineTraceSnapshot(
            requestID: await apiClient.latestDebugRequestID(),
            requestBody: requestBody,
            responseBody: responseBody,
            rawErrorBody: nil,
            statusCode: 200,
            failedStage: nil
        )
        await debugTraceStore.set(trace)

        return ReflectionServiceResult(
            title: response.title,
            body: response.body,
            evidenceSummary: response.evidenceSummary,
            confidence: response.confidence,
            sourceRecordIDs: response.sourceRecordIDs.compactMap(UUID.init(uuidString:)),
            debugTrace: trace
        )
    }

    private func makeReflectionPayload(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) -> MoryAPIClient.ReflectionPayload {
        let analyzePayload = requestBuilder.build(
            record: record,
            artifacts: artifacts,
            knownEntities: knownEntities,
            analysisReason: "manual"
        )
        return MoryAPIClient.ReflectionPayload(
            recordShell: analyzePayload.recordShell,
            artifacts: analyzePayload.artifacts,
            linkedArcID: linkedArcID?.uuidString,
            knownEntities: analyzePayload.knownEntities,
            prompt: prompt?.trimmedOrNil
        )
    }
}
