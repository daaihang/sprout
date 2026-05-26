import Foundation

struct RemotePushDeliveryPayload: Hashable, Sendable {
    var intentID: UUID
    var kind: String
    var title: String
    var body: String
    var privacyLevel: String
    var targetType: String
    var targetID: UUID
    var deepLink: String?
    var scheduledAt: Date
}
