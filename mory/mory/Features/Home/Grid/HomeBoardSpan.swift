import Foundation

nonisolated enum HomeBoardItemLayer: String, Codable, CaseIterable, Identifiable, Sendable {
    case userBoard
    case suggestion

    var id: String { rawValue }
}

nonisolated struct HomeBoardSpan: Codable, Hashable, Sendable {
    static let allowedSizes: [HomeBoardSpan] = [
        .init(widthColumns: 1, heightUnits: 1),
        .init(widthColumns: 2, heightUnits: 1),
        .init(widthColumns: 2, heightUnits: 2),
        .init(widthColumns: 3, heightUnits: 1),
        .init(widthColumns: 3, heightUnits: 2),
        .init(widthColumns: 3, heightUnits: 3),
        .init(widthColumns: 4, heightUnits: 1),
        .init(widthColumns: 4, heightUnits: 2),
        .init(widthColumns: 4, heightUnits: 3),
    ]

    var widthColumns: Int
    var heightUnits: Int

    init(widthColumns: Int, heightUnits: Int) {
        self.widthColumns = max(1, widthColumns)
        self.heightUnits = max(1, heightUnits)
    }

    func clamped(to columns: Int) -> HomeBoardSpan {
        HomeBoardSpan(
            widthColumns: min(max(1, widthColumns), max(1, columns)),
            heightUnits: max(1, heightUnits)
        )
    }
}

nonisolated struct HomeBoardItemLayout: Codable, Hashable, Sendable {
    var span: HomeBoardSpan
    var layer: HomeBoardItemLayer
    var userSortIndex: Double?
    var acceptedAt: Date?
    var feedbackAdjustment: Double
    var feedbackUpdatedAt: Date?

    init(
        span: HomeBoardSpan,
        layer: HomeBoardItemLayer,
        userSortIndex: Double? = nil,
        acceptedAt: Date? = nil,
        feedbackAdjustment: Double = 0,
        feedbackUpdatedAt: Date? = nil
    ) {
        self.span = span
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
