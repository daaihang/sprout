import Foundation

struct MoryAPIConfiguration: Sendable {
    let baseURL: URL
    let authPath: String
    let analysisPath: String
    let devAuthIdentityToken: String

    init(
        baseURL: URL,
        authPath: String = "/auth/apple",
        analysisPath: String = "/api/analysis/records",
        devAuthIdentityToken: String = "dev-user"
    ) {
        self.baseURL = baseURL
        self.authPath = authPath
        self.analysisPath = analysisPath
        self.devAuthIdentityToken = devAuthIdentityToken
    }

    static func fromBundle(_ bundle: Bundle = .main) -> MoryAPIConfiguration {
        let baseURLString = bundle.object(forInfoDictionaryKey: "MORY_API_BASE_URL") as? String
        let identityToken = bundle.object(forInfoDictionaryKey: "MORY_DEV_AUTH_IDENTITY_TOKEN") as? String

        return MoryAPIConfiguration(
            baseURL: URL(string: baseURLString?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "http://127.0.0.1:8080")!,
            devAuthIdentityToken: identityToken?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "dev-user"
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
