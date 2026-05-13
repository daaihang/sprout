import Foundation
import SwiftData

@MainActor
struct CompositionStateRepository {
    struct ResolvedBoardContext {
        let board: DayBoard
        let boardKey: String
    }

    struct ResolvedCompositionState {
        var span: ContainerSpan
        var zIndex: Int
        var rotationDegrees: Double
        var scale: Double
    }

    let modelContext: ModelContext

    func boardContext(for date: Date) -> ResolvedBoardContext {
        let boardKey = boardKey(for: date)
        if let existing = board(boardKey: boardKey) {
            return ResolvedBoardContext(board: existing, boardKey: boardKey)
        }

        let created = DayBoard(
            boardKey: boardKey,
            boardDate: startOfDay(for: date),
            title: boardTitle(for: date)
        )
        modelContext.insert(created)
        return ResolvedBoardContext(board: created, boardKey: boardKey)
    }

    func boardKey(for date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "day-%04d-%02d-%02d", year, month, day)
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

    func state(boardKey: String, itemKey: String) -> CompositionItemState? {
        var descriptor = FetchDescriptor<CompositionItemState>(
            predicate: #Predicate<CompositionItemState> { state in
                state.boardKey == boardKey && state.itemKey == itemKey
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func resolvedState(
        boardKey: String,
        itemKey: String,
        fallbackSpan: ContainerSpan,
        fallbackZIndex: Int,
        fallbackRotationDegrees: Double,
        fallbackScale: Double
    ) -> ResolvedCompositionState {
        guard let state = state(boardKey: boardKey, itemKey: itemKey) else {
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
        itemKey: String,
        targetType: String,
        targetID: UUID,
        span: ContainerSpan,
        zIndex: Int,
        rotationDegrees: Double,
        scale: Double
    ) {
        if let existing = state(boardKey: boardKey, itemKey: itemKey) {
            existing.boardID = boardID
            existing.targetType = targetType
            existing.targetID = targetID
            existing.setSpan(span)
            existing.setVisualState(zIndex: zIndex, rotationDegrees: rotationDegrees, scale: scale)
            return
        }

        let created = CompositionItemState(
            boardID: boardID,
            boardKey: boardKey,
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
