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
        let artifacts = memoryView?.artifacts ?? []
        let artifactsByKind = Dictionary(
            grouping: artifacts,
            by: \.kind
        )

        let artifactCards = primaryArtifactCards(
            for: record,
            artifacts: artifacts,
            stateRepository: stateRepository,
            compositionKey: compositionKey
        )
        let coveredSections = Set(artifactCards.map(\.focusedSection))

        let legacyFallbackCards = RecordMapper.allCards(
            record: record
        )
        .filter { !coveredSections.contains($0.focusedSection) }
        .enumerated()
        .map { index, card in
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
            let fallbackZIndex = artifactCards.count + index
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

        let coveredArtifactIDs = Set(
            (artifactCards + legacyFallbackCards)
                .filter { $0.targetType == .artifact }
                .map(\.targetID)
        )

        return artifactCards + legacyFallbackCards + supplementalArtifactCards(
            for: record,
            artifacts: artifacts,
            coveredArtifactIDs: coveredArtifactIDs,
            stateRepository: stateRepository,
            compositionKey: compositionKey,
            baseIndexOffset: artifactCards.count + legacyFallbackCards.count
        )
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
            return nil
        case .music:
            return artifactsByKind[.music]?.first
        case .audio:
            return nil
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

    private func primaryArtifactCards(
        for record: Record,
        artifacts: [Artifact],
        stateRepository: CompositionStateRepository,
        compositionKey: String
    ) -> [CompositionProjectionCard] {
        artifacts
            .filter(isPrimaryArtifact)
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.createdAt < rhs.createdAt
            }
            .enumerated()
            .compactMap { index, artifact in
                let fallbackSpanKey = artifactSpanKey(for: artifact)
                let fallbackID = "\(record.id.uuidString)-\(fallbackSpanKey)"
                let section = focusedSection(for: artifact)

                guard let rendered = artifactRenderer.renderCard(
                    for: artifact,
                    record: record,
                    focusedSection: section,
                    fallbackID: fallbackID,
                    fallbackSpanKey: fallbackSpanKey
                ) else {
                    return nil
                }

                let fallbackSpan = sizeLimits(for: rendered.cardType).defaultSpan
                let itemKey = "\(record.id.uuidString)-\(rendered.spanKey)"
                let fallbackRotation = stickerRotation(for: rendered.id)
                let fallbackScale = stickerScale(for: rendered.id)
                let resolvedState = stateRepository.resolvedState(
                    compositionKey: compositionKey,
                    itemKey: itemKey,
                    fallbackSpan: fallbackSpan,
                    fallbackZIndex: index,
                    fallbackRotationDegrees: fallbackRotation,
                    fallbackScale: fallbackScale
                )

                return CompositionProjectionCard(
                    id: rendered.id,
                    spanKey: rendered.spanKey,
                    compositionItemKey: itemKey,
                    cardType: rendered.cardType,
                    targetType: .artifact,
                    targetID: artifact.id,
                    record: rendered.record,
                    focusedSection: rendered.focusedSection,
                    columns: resolvedState.span.widthColumns,
                    units: resolvedState.span.heightUnits,
                    zIndex: resolvedState.zIndex,
                    rotationDegrees: resolvedState.rotationDegrees,
                    scale: resolvedState.scale,
                    cardView: rendered.cardView
                )
            }
    }

    private func isPrimaryArtifact(_ artifact: Artifact) -> Bool {
        switch artifact.kind {
        case .photo, .audio:
            return false
        case .text, .link, .todo, .music, .location, .weather, .personMention, .decisionNote:
            return true
        case .book, .film, .game, .ticket, .healthMetric:
            return false
        }
    }

    private func focusedSection(for artifact: Artifact) -> RecordSection {
        switch artifact.kind {
        case .text, .decisionNote, .book, .film, .game, .ticket, .healthMetric:
            return .text
        case .photo:
            return .photo
        case .audio:
            return .audio
        case .link:
            return .link
        case .todo:
            return .todo
        case .music:
            return .music
        case .location:
            return .map
        case .weather:
            return .weather
        case .personMention:
            return .people
        }
    }

    private func artifactSpanKey(for artifact: Artifact) -> String {
        switch artifact.kind {
        case .text:
            return "text"
        case .link:
            return "link"
        case .todo:
            return "todo"
        case .music:
            return "music"
        case .location:
            return "map"
        case .weather:
            return "weather"
        case .personMention:
            return "people"
        case .photo:
            return "photo"
        case .audio:
            return "audio"
        case .decisionNote, .book, .film, .game, .ticket, .healthMetric:
            return "artifact-\(artifact.kind.rawValue)-\(artifact.id.uuidString)"
        }
    }

    private func supplementalArtifactCards(
        for record: Record,
        artifacts: [Artifact],
        coveredArtifactIDs: Set<UUID>,
        stateRepository: CompositionStateRepository,
        compositionKey: String,
        baseIndexOffset: Int
    ) -> [CompositionProjectionCard] {
        let supplementalKinds: Set<ArtifactKind> = [.book, .film, .game, .ticket, .healthMetric]

        return artifacts
            .filter { supplementalKinds.contains($0.kind) && !coveredArtifactIDs.contains($0.id) }
            .enumerated()
            .compactMap { index, artifact in
                let fallbackID = "\(record.id.uuidString)-artifact-\(artifact.kind.rawValue)-\(artifact.id.uuidString)"
                let fallbackSpanKey = "artifact-\(artifact.kind.rawValue)-\(artifact.id.uuidString)"

                guard let rendered = artifactRenderer.renderCard(
                    for: artifact,
                    record: record,
                    focusedSection: .text,
                    fallbackID: fallbackID,
                    fallbackSpanKey: fallbackSpanKey
                ) else {
                    return nil
                }

                let fallbackSpan = sizeLimits(for: rendered.cardType).defaultSpan
                let itemKey = "\(record.id.uuidString)-\(rendered.spanKey)"
                let fallbackZIndex = baseIndexOffset + index
                let fallbackRotation = stickerRotation(for: rendered.id)
                let fallbackScale = stickerScale(for: rendered.id)
                let resolvedState = stateRepository.resolvedState(
                    compositionKey: compositionKey,
                    itemKey: itemKey,
                    fallbackSpan: fallbackSpan,
                    fallbackZIndex: fallbackZIndex,
                    fallbackRotationDegrees: fallbackRotation,
                    fallbackScale: fallbackScale
                )

                return CompositionProjectionCard(
                    id: rendered.id,
                    spanKey: rendered.spanKey,
                    compositionItemKey: itemKey,
                    cardType: rendered.cardType,
                    targetType: .artifact,
                    targetID: artifact.id,
                    record: rendered.record,
                    focusedSection: rendered.focusedSection,
                    columns: resolvedState.span.widthColumns,
                    units: resolvedState.span.heightUnits,
                    zIndex: resolvedState.zIndex,
                    rotationDegrees: resolvedState.rotationDegrees,
                    scale: resolvedState.scale,
                    cardView: rendered.cardView
                )
            }
    }
}
