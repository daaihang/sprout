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
    let presentationKey: String
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
        return artifactCards(
            for: record,
            artifacts: artifacts,
            stateRepository: stateRepository,
            compositionKey: compositionKey
        )
    }

    private func artifactCards(
        for record: Record,
        artifacts: [Artifact],
        stateRepository: CompositionStateRepository,
        compositionKey: String
    ) -> [CompositionProjectionCard] {
        artifacts
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

                let fallbackSpan = sizeLimits(for: rendered.presentationKey).defaultSpan
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
                    presentationKey: rendered.presentationKey,
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

}
