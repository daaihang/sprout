import Foundation

struct MoryAPIConfiguration: Sendable {
    let baseURL: URL
    let authPath: String
    let analysisPath: String

    init(
        baseURL: URL,
        authPath: String = "/auth/apple",
        analysisPath: String = "/api/analysis/records"
    ) {
        self.baseURL = baseURL
        self.authPath = authPath
        self.analysisPath = analysisPath
    }

    static func fromBundle(_ bundle: Bundle = .main) -> MoryAPIConfiguration {
        let baseURLString = bundle.object(forInfoDictionaryKey: "MORY_API_BASE_URL") as? String

        return MoryAPIConfiguration(
            baseURL: URL(string: baseURLString?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "http://127.0.0.1:8080")!
        )
    }

    func url(for path: String) -> URL {
        baseURL.appending(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
