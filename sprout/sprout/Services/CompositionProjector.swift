import SwiftUI

enum CompositionProjectionTargetType: String, Sendable {
    case record
    case artifact
    case arc
    case reflection
    case system
}

struct CompositionProjectionCard: Identifiable {
    let id: String
    let spanKey: String
    let compositionItemKey: String
    let cardType: String
    let targetType: CompositionProjectionTargetType
    let targetID: UUID
    let record: Record
    let focusedSection: RecordSection
    let columns: Int
    let units: Int
    let zIndex: Int
    let rotationDegrees: Double
    let scale: Double
    let cardView: AnyView
}

@MainActor
struct CompositionProjector {
    private let artifactRenderer = ArtifactRenderer()

    func projectCards(
        for record: Record,
        memoryRepository: SproutMemoryRepository,
        stateRepository: CompositionStateRepository,
        compositionKey: String
    ) -> [CompositionProjectionCard] {
        let memoryView = memoryRepository.memoryView(for: record.id)
        let artifactsByKind = Dictionary(
            grouping: memoryView?.artifacts ?? [],
            by: \.kind
        )

        return RecordMapper.allCards(record: record).enumerated().map { index, card in
            let resolvedTarget = projectionTarget(
                for: card,
                record: record,
                artifactsByKind: artifactsByKind
            )
            let renderedCard = renderedCardInfo(
                for: card,
                target: resolvedTarget,
                record: record,
                artifactsByKind: artifactsByKind
            )
            let fallbackSpan = ContainerSpan(widthColumns: card.columns, heightUnits: card.units)
            let itemKey = compositionItemKey(for: renderedCard)
            let fallbackZIndex = index
            let fallbackRotation = stickerRotation(for: renderedCard.id)
            let fallbackScale = stickerScale(for: renderedCard.id)
            let resolvedState = stateRepository.resolvedState(
                compositionKey: compositionKey,
                itemKey: itemKey,
                fallbackSpan: fallbackSpan,
                fallbackZIndex: fallbackZIndex,
                fallbackRotationDegrees: fallbackRotation,
                fallbackScale: fallbackScale
            )

            return CompositionProjectionCard(
                id: renderedCard.id,
                spanKey: renderedCard.spanKey,
                compositionItemKey: itemKey,
                cardType: renderedCard.cardType,
                targetType: resolvedTarget.type,
                targetID: resolvedTarget.id,
                record: renderedCard.record,
                focusedSection: renderedCard.focusedSection,
                columns: resolvedState.span.widthColumns,
                units: resolvedState.span.heightUnits,
                zIndex: resolvedState.zIndex,
                rotationDegrees: resolvedState.rotationDegrees,
                scale: resolvedState.scale,
                cardView: renderedCard.cardView
            )
        }
    }

    private func compositionItemKey(for card: DashboardCardInfo) -> String {
        "\(card.record.id.uuidString)-\(card.spanKey)"
    }

    private func renderedCardInfo(
        for card: DashboardCardInfo,
        target: (type: CompositionProjectionTargetType, id: UUID),
        record: Record,
        artifactsByKind: [ArtifactKind: [Artifact]]
    ) -> DashboardCardInfo {
        guard target.type == .artifact,
              let artifact = artifactTarget(for: card, artifactsByKind: artifactsByKind),
              let rendered = artifactRenderer.renderCard(
                for: artifact,
                record: record,
                focusedSection: card.focusedSection,
                fallbackID: card.id,
                fallbackSpanKey: card.spanKey
              ) else {
            return card
        }

        return DashboardCardInfo(
            id: rendered.id,
            spanKey: rendered.spanKey,
            cardType: rendered.cardType,
            record: rendered.record,
            focusedSection: rendered.focusedSection,
            columns: card.columns,
            units: card.units,
            zIndex: card.zIndex,
            rotationDegrees: card.rotationDegrees,
            scale: card.scale,
            cardView: rendered.cardView
        )
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
