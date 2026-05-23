import Foundation

struct ExternalCaptureDeepLink: Hashable, Sendable {
    enum Action: String, Sendable {
        case compose
    }

    var itemID: UUID
    var action: Action

    init?(url: URL) {
        guard url.scheme == "mory", url.host == "external-capture" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard
            let idValue = components?.queryItems?.first(where: { $0.name == "id" })?.value,
            let itemID = UUID(uuidString: idValue)
        else {
            return nil
        }
        let actionValue = components?.queryItems?.first(where: { $0.name == "action" })?.value
        self.itemID = itemID
        self.action = Action(rawValue: actionValue ?? "") ?? .compose
    }
}
