import Foundation
import SwiftData

@MainActor
struct CompositionStateRepository {
    struct ResolvedCompositionContext {
        let board: DayBoard
        let composition: BoardComposition
        let boardKey: String
        let compositionKey: String
    }

    struct ResolvedCompositionState {
        var span: ContainerSpan
        var zIndex: Int
        var rotationDegrees: Double
        var scale: Double
    }

    let modelContext: ModelContext

    func compositionContext(for date: Date) -> ResolvedCompositionContext {
        let boardKey = Self.boardKey(for: date)
        let board = board(boardKey: boardKey) ?? {
            let created = DayBoard(
                boardKey: boardKey,
                boardDate: startOfDay(for: date),
                title: boardTitle(for: date)
            )
            modelContext.insert(created)
            return created
        }()
        let compositionKey = compositionKey(for: boardKey)
        let composition = composition(boardID: board.id, compositionKey: compositionKey) ?? {
            let created = BoardComposition(
                boardID: board.id,
                compositionKey: compositionKey,
                title: board.title
            )
            modelContext.insert(created)
            return created
        }()
        return ResolvedCompositionContext(
            board: board,
            composition: composition,
            boardKey: boardKey,
            compositionKey: compositionKey
        )
    }

    func boardKey(for date: Date) -> String {
        Self.boardKey(for: date)
    }

    static func boardKey(for date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "day-%04d-%02d-%02d", year, month, day)
    }

    func compositionKey(for boardKey: String) -> String {
        "\(boardKey):primary"
    }

    func board(boardKey: String) -> DayBoard? {
        var descriptor = FetchDescriptor<DayBoard>(
            predicate: #Predicate<DayBoard> { board in
                board.boardKey == boardKey
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func composition(boardID: UUID, compositionKey: String) -> BoardComposition? {
        var descriptor = FetchDescriptor<BoardComposition>(
            predicate: #Predicate<BoardComposition> { composition in
                composition.boardID == boardID && composition.compositionKey == compositionKey
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func state(compositionKey: String, itemKey: String) -> CompositionItemState? {
        var descriptor = FetchDescriptor<CompositionItemState>(
            predicate: #Predicate<CompositionItemState> { state in
                state.compositionKey == compositionKey && state.itemKey == itemKey
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func resolvedState(
        compositionKey: String,
        itemKey: String,
        fallbackSpan: ContainerSpan,
        fallbackZIndex: Int,
        fallbackRotationDegrees: Double,
        fallbackScale: Double
    ) -> ResolvedCompositionState {
        guard let state = state(compositionKey: compositionKey, itemKey: itemKey) else {
            return ResolvedCompositionState(
                span: fallbackSpan,
                zIndex: fallbackZIndex,
                rotationDegrees: fallbackRotationDegrees,
                scale: fallbackScale
            )
        }

        return ResolvedCompositionState(
            span: state.span,
            zIndex: state.zIndex,
            rotationDegrees: state.rotationDegrees,
            scale: state.scale
        )
    }

    func upsertState(
        boardID: UUID,
        boardKey: String,
        compositionID: UUID,
        compositionKey: String,
        itemKey: String,
        targetType: String,
        targetID: UUID,
        span: ContainerSpan,
        zIndex: Int,
        rotationDegrees: Double,
        scale: Double
    ) {
        if let existing = state(compositionKey: compositionKey, itemKey: itemKey) {
            existing.boardID = boardID
            existing.boardKey = boardKey
            existing.compositionID = compositionID
            existing.compositionKey = compositionKey
            existing.targetType = targetType
            existing.targetID = targetID
            existing.setSpan(span)
            existing.setVisualState(zIndex: zIndex, rotationDegrees: rotationDegrees, scale: scale)
            try? modelContext.save()
            return
        }

        let created = CompositionItemState(
            boardID: boardID,
            boardKey: boardKey,
            compositionID: compositionID,
            compositionKey: compositionKey,
            itemKey: itemKey,
            targetType: targetType,
            targetID: targetID,
            widthColumns: span.widthColumns,
            heightUnits: span.heightUnits,
            zIndex: zIndex,
            rotationDegrees: rotationDegrees,
            scale: scale
        )
        modelContext.insert(created)
        try? modelContext.save()
    }

    private func startOfDay(for date: Date) -> Date {
        Calendar(identifier: .gregorian).startOfDay(for: date)
    }

    private func boardTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: startOfDay(for: date))
    }
}
