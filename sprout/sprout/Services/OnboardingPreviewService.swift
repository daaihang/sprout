import Foundation
import Observation

@Observable
@MainActor
final class OnboardingPreviewService {
    struct PreviewResult: Decodable {
        let tags: [String]
        let emotion: Emotion
        let insight: String
        let followUp: FollowUp?
        let mode: String

        struct Emotion: Decodable {
            let label: String
            let intensity: Int?
        }

        struct FollowUp: Decodable {
            let question: String
        }

        private enum CodingKeys: String, CodingKey {
            case tags
            case emotion
            case insight
            case followUp = "follow_up"
            case mode
        }
    }

    var isLoading = false
    var previewText = ""
    var previewResult: PreviewResult? = nil
    var errorMessage: String? = nil

    func runPreview() async {
        let content = previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            errorMessage = "Write a short memory to preview the AI reflection."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var request = URLRequest(url: try endpoint("/api/onboarding/analyze-preview"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "record": [
                    "content": content,
                ],
            ])

            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response: response, data: data)
            previewResult = try JSONDecoder().decode(PreviewResult.self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func endpoint(_ path: String) throws -> URL {
        guard let url = URL(string: MoryConfig.apiBaseURL + path) else {
            throw OnboardingPreviewError.invalidBaseURL
        }
        return url
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OnboardingPreviewError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(ServerErrorResponse.self, from: data).error) ?? "Preview request failed (\(httpResponse.statusCode))"
            throw OnboardingPreviewError.server(message)
        }
    }
}

enum OnboardingPreviewError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "MORY_API_BASE_URL is not configured."
        case .invalidResponse:
            return "Invalid server response."
        case let .server(message):
            return message
        }
    }
}
