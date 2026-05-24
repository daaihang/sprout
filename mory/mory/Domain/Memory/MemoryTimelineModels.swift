import Foundation

struct TimelineDayGroup: Identifiable, Hashable, Sendable {
    let date: Date
    let memories: [MemorySummary]
    var id: Date { date }
    var dayLabel: String { date.formatted(date: .abbreviated, time: .omitted) }
}

enum TimelineGranularity: String, CaseIterable, Identifiable, Sendable {
    case day, week, month
    var id: String { rawValue }
}

struct TimelineSnapshot: Hashable, Sendable {
    let granularity: TimelineGranularity
    let groups: [TimelineDayGroup]
    let totalCount: Int
}
