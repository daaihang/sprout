import Foundation

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
