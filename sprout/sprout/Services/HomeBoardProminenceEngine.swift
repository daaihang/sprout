import Foundation

enum HomeBoardItemKind: String, Sendable {
    case systemTodayInHistory
    case temporalArc
    case phaseReflection
    case recordCard
}

struct HomeBoardProminence {
    var order: Double
    var fallbackSpan: ContainerSpan
    var fallbackZIndex: Int
}

struct HomeBoardProminenceEngine {
    func prominence(
        for kind: HomeBoardItemKind,
        record: Record? = nil,
        arc: TemporalArc? = nil,
        reflection: ReflectionSnapshot? = nil,
        cardType: String? = nil
    ) -> HomeBoardProminence {
        switch kind {
        case .systemTodayInHistory:
            return HomeBoardProminence(
                order: -10_000,
                fallbackSpan: sizeLimits(for: DashboardSystemCardConfig.todayInHistoryKind).clamped(
                    span: ContainerSpan(widthColumns: 4, heightUnits: 4)
                ),
                fallbackZIndex: -10_000
            )
        case .temporalArc:
            let baseHeight = arc.map(arcHeightUnits(for:)) ?? 4
            let score = arc.map(arcProminenceScore(for:)) ?? 0
            return HomeBoardProminence(
                order: -9_700 - score,
                fallbackSpan: sizeLimits(for: "text").clamped(
                    span: ContainerSpan(widthColumns: 4, heightUnits: baseHeight)
                ),
                fallbackZIndex: -9_700
            )
        case .phaseReflection:
            let baseHeight = reflection.map(reflectionHeightUnits(for:)) ?? 2
            let score = reflection.map(reflectionProminenceScore(for:)) ?? 0
            return HomeBoardProminence(
                order: -9_620 - score,
                fallbackSpan: sizeLimits(for: "text").clamped(
                    span: ContainerSpan(widthColumns: 4, heightUnits: baseHeight)
                ),
                fallbackZIndex: -9_620
            )
        case .recordCard:
            let order = record.map(recordOrder(for:)) ?? 0
            let span = sizeLimits(for: cardType ?? "text").clamped(
                span: record?.containerSpan ?? ContainerSpan(widthColumns: 4, heightUnits: 4)
            )
            return HomeBoardProminence(
                order: order,
                fallbackSpan: span,
                fallbackZIndex: 0
            )
        }
    }

    private func recordOrder(for record: Record) -> Double {
        record.dashboardOrder == 0 ? record.createdAt.timeIntervalSince1970 : record.dashboardOrder
    }

    private func arcHeightUnits(for arc: TemporalArc) -> Int {
        if arc.sourceRecordIDs.count >= 4 || arc.clusterStrength >= 0.62 {
            return 4
        }
        return 2
    }

    private func arcProminenceScore(for arc: TemporalArc) -> Double {
        Double(min(arc.sourceRecordIDs.count, 8)) * 4 + arc.intensityScore * 2
    }

    private func reflectionHeightUnits(for reflection: ReflectionSnapshot) -> Int {
        reflection.body.count > 120 ? 4 : 2
    }

    private func reflectionProminenceScore(for reflection: ReflectionSnapshot) -> Double {
        Double(min(reflection.body.count / 40, 6)) * 3
    }
}
