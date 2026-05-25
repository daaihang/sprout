import Foundation

extension MoryAPIClient {
    struct ReflectionPayload: Encodable, Sendable {
        var recordShell: AnalysisRecordPayload.RecordShellPayload
        var artifacts: [AnalysisRecordPayload.ArtifactPayload]
        var linkedArcID: String?
        var knownEntities: [AnalysisRecordPayload.KnownEntityPayload]
        var prompt: String?
        var debugOptions: AnalysisRecordPayload.DebugOptionsPayload? = AnalysisRecordPayload.DebugOptionsPayload.current()

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

    func analyzeMemory(
        payload: AnalysisRequestPayload,
        bearerToken: String
    ) async throws -> AnalysisResponseEnvelope {
        var request = URLRequest(url: configuration.url(for: "/api/analyze"))
        let requestID = makeDebugRequestID(prefix: "analysis")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
        request.httpBody = try encoder.encode(payload)

        do {
            let (data, response) = try await session.data(for: request)
            let decoded = try decodeResponse(data: data, response: response, as: AnalysisResponseEnvelope.self, failedStage: "analysis", requestID: requestID)
            await debugTraceBox.setRequestID(responseRequestID(response) ?? requestID)
            return decoded
        } catch {
            throw normalize(error: error, failedStage: "analysis")
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
