import Foundation

struct MoryAPIConfiguration: Sendable {
    let baseURL: URL
    let authPath: String

    init(
        baseURL: URL,
        authPath: String = "/auth/apple"
    ) {
        self.baseURL = baseURL
        self.authPath = authPath
    }

    static func fromBundle(_ bundle: Bundle = .main) -> MoryAPIConfiguration {
        let baseURLString = bundle.object(forInfoDictionaryKey: "MORY_API_BASE_URL") as? String
        let raw = baseURLString?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? defaultBaseURL.absoluteString

        guard let url = URL(string: raw) else {
            fatalError("MoryAPIConfiguration: invalid base URL string: \(raw)")
        }

        return MoryAPIConfiguration(baseURL: url)
    }

    static var defaultBaseURL: URL {
        #if targetEnvironment(simulator)
        URL(string: "http://127.0.0.1:8080")!
        #else
        URL(string: "https://sprout-god7g.fly.dev")!
        #endif
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
