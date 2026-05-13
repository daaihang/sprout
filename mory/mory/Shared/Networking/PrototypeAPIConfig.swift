import Foundation

struct PrototypeAPIConfig: Sendable {
    var baseURL: URL
    var bearerToken: String? = nil

    static let preview = PrototypeAPIConfig(
        baseURL: URL(string: "https://sprout-god7g.fly.dev")!
    )
}
