import Foundation

enum PrototypeAPIError: Error, LocalizedError {
    case invalidResponse
    case unsuccessfulStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid server response."
        case let .unsuccessfulStatus(code, body):
            "Request failed with status \(code): \(body)"
        }
    }
}

final class PrototypeAPIClient: Sendable {
    private let config: PrototypeAPIConfig
    private let session: URLSession

    init(config: PrototypeAPIConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func analyzePreview(_ payload: AnalyzeRequestPayload) async throws -> AnalyzeResponseEnvelope {
        try await request(.analyzePreview, payload: payload)
    }

    private func request<T: Decodable>(_ endpoint: PrototypeEndpoint, payload: AnalyzeRequestPayload) async throws -> T {
        let url = config.baseURL.appendingPathComponent(
            endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearerToken = config.bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PrototypeAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PrototypeAPIError.unsuccessfulStatus(
                httpResponse.statusCode,
                String(data: data, encoding: .utf8) ?? ""
            )
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
