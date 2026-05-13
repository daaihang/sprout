import Foundation

enum PrototypeEndpoint {
    case analyzePreview

    var path: String {
        switch self {
        case .analyzePreview:
            "/api/onboarding/analyze-preview"
        }
    }
}
