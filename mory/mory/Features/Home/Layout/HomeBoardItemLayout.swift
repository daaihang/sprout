import Foundation

nonisolated enum HomeBoardItemLayer: String, Codable, CaseIterable, Identifiable, Sendable {
    case userBoard
    case suggestion

    var id: String { rawValue }
}

nonisolated struct HomeBoardItemLayout: Codable, Hashable, Sendable {
    var layer: HomeBoardItemLayer
    var userSortIndex: Double?
    var acceptedAt: Date?
    var feedbackAdjustment: Double
    var feedbackUpdatedAt: Date?

    init(
        layer: HomeBoardItemLayer,
        userSortIndex: Double? = nil,
        acceptedAt: Date? = nil,
        feedbackAdjustment: Double = 0,
        feedbackUpdatedAt: Date? = nil
    ) {
        self.layer = layer
        self.userSortIndex = userSortIndex
        self.acceptedAt = acceptedAt
        self.feedbackAdjustment = feedbackAdjustment
        self.feedbackUpdatedAt = feedbackUpdatedAt
    }

    var isUserControlled: Bool {
        layer == .userBoard
    }
}
