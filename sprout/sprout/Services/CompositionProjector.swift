import SwiftUI

enum CompositionProjectionTargetType: String, Sendable {
    case record
    case artifact
    case arc
    case system
}

struct CompositionProjectionCard: Identifiable {
    let id: String
    let spanKey: String
    let cardType: String
    let targetType: CompositionProjectionTargetType
    let targetID: UUID
    let record: Record
    let focusedSection: RecordSection
    let columns: Int
    let units: Int
    let cardView: AnyView
}

@MainActor
struct CompositionProjector {
    func projectCards(
        for record: Record,
        memoryRepository: SproutMemoryRepository
    ) -> [CompositionProjectionCard] {
        let memoryView = memoryRepository.memoryView(for: record.id)
        let artifactsByKind = Dictionary(
            grouping: memoryView?.artifacts ?? [],
            by: \.kind
        )

        return RecordMapper.allCards(record: record).map { card in
            let resolvedTarget = projectionTarget(
                for: card,
                record: record,
                artifactsByKind: artifactsByKind
            )

            return CompositionProjectionCard(
                id: card.id,
                spanKey: card.spanKey,
                cardType: card.cardType,
                targetType: resolvedTarget.type,
                targetID: resolvedTarget.id,
                record: card.record,
                focusedSection: card.focusedSection,
                columns: card.columns,
                units: card.units,
                cardView: card.cardView
            )
        }
    }

    private func projectionTarget(
        for card: DashboardCardInfo,
        record: Record,
        artifactsByKind: [ArtifactKind: [Artifact]]
    ) -> (type: CompositionProjectionTargetType, id: UUID) {
        if let artifact = artifactTarget(for: card, artifactsByKind: artifactsByKind) {
            return (.artifact, artifact.id)
        }

        return (.record, record.id)
    }

    private func artifactTarget(
        for card: DashboardCardInfo,
        artifactsByKind: [ArtifactKind: [Artifact]]
    ) -> Artifact? {
        switch card.focusedSection {
        case .text:
            return artifactsByKind[.text]?.first
        case .photo:
            return artifactsByKind[.photo]?.first
        case .music:
            return artifactsByKind[.music]?.first
        case .audio:
            return artifactsByKind[.audio]?.first
        case .link:
            return artifactsByKind[.link]?.first
        case .weather:
            return artifactsByKind[.weather]?.first
        case .todo:
            return artifactsByKind[.todo]?.first
        case .map:
            return artifactsByKind[.location]?.first
        case .people:
            return artifactsByKind[.personMention]?.first
        case .emotion, .activity, .todayInHistory:
            return nil
        }
    }
}
