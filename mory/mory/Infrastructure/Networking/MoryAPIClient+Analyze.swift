import Foundation

extension MoryAPIClient {
    struct ReflectionPayload: Encodable, Sendable {
        var recordShell: AnalyzeRequestPayload.RecordShellPayload
        var artifacts: [AnalyzeRequestPayload.ArtifactPayload]
        var linkedArcID: String?
        var knownEntities: [AnalyzeRequestPayload.KnownEntityPayload]
        var prompt: String?
        var debugOptions: AnalyzeRequestPayload.DebugOptionsPayload? = AnalyzeRequestPayload.DebugOptionsPayload.current()

        enum CodingKeys: String, CodingKey {
            case recordShell = "record_shell"
            case artifacts
            case linkedArcID = "linked_arc_id"
            case knownEntities = "known_entities"
            case prompt
            case debugOptions = "debug_options"
        }
    }

    struct ReflectionResponse: Decodable, Sendable {
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

    func analyzeRecords(
        payload: AnalyzeRequestPayload,
        bearerToken: String
    ) async throws -> AnalyzeResponseEnvelope {
        var request = URLRequest(url: configuration.url(for: configuration.analysisPath))
        let requestID = makeDebugRequestID(prefix: "analysis")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
        request.httpBody = try encoder.encode(payload)

        do {
            let (data, response) = try await session.data(for: request)
            let decoded = try decodeResponse(data: data, response: response, as: AnalyzeResponseEnvelope.self, failedStage: "analysis", requestID: requestID)
            await debugTraceBox.setRequestID(responseRequestID(response) ?? requestID)
            return decoded
        } catch {
            throw normalize(error: error, failedStage: "analysis")
        }
    }

    func analyzeRecordsV7(
        payload: AnalyzeV7RequestPayload,
        bearerToken: String
    ) async throws -> AnalyzeV7ResponseEnvelope {
        var request = URLRequest(url: configuration.url(for: "/api/analyze/v7"))
        let requestID = makeDebugRequestID(prefix: "analysis-v7")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
        request.httpBody = try encoder.encode(payload)

        do {
            let (data, response) = try await session.data(for: request)
            let decoded = try decodeResponse(data: data, response: response, as: AnalyzeV7ResponseEnvelope.self, failedStage: "analysis_v7", requestID: requestID)
            await debugTraceBox.setRequestID(responseRequestID(response) ?? requestID)
            return decoded
        } catch {
            throw normalize(error: error, failedStage: "analysis_v7")
        }
    }

    func generateReflection(
        payload: ReflectionPayload,
        bearerToken: String
    ) async throws -> ReflectionResponse {
        var request = URLRequest(url: configuration.url(for: "/api/reflections/generate"))
        let requestID = makeDebugRequestID(prefix: "reflection-generate")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
        request.httpBody = try encoder.encode(payload)

        do {
            let (data, response) = try await session.data(for: request)
            let decoded = try decodeResponse(data: data, response: response, as: ReflectionResponse.self, failedStage: "reflection_generate", requestID: requestID)
            await debugTraceBox.setRequestID(responseRequestID(response) ?? requestID)
            return decoded
        } catch {
            throw normalize(error: error, failedStage: "reflection_generate")
        }
    }

    func replayReflection(
        payload: ReflectionPayload,
        bearerToken: String
    ) async throws -> ReflectionResponse {
        var request = URLRequest(url: configuration.url(for: "/api/reflections/replay"))
        let requestID = makeDebugRequestID(prefix: "reflection-replay")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
        request.httpBody = try encoder.encode(payload)

        do {
            let (data, response) = try await session.data(for: request)
            let decoded = try decodeResponse(data: data, response: response, as: ReflectionResponse.self, failedStage: "reflection_replay", requestID: requestID)
            await debugTraceBox.setRequestID(responseRequestID(response) ?? requestID)
            return decoded
        } catch {
            throw normalize(error: error, failedStage: "reflection_replay")
        }
    }

}
