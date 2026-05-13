import Foundation
import SwiftData

@MainActor
struct CompositionStateRepository {
    let modelContext: ModelContext

    func boardKey(for date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "day-%04d-%02d-%02d", year, month, day)
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

    func resolvedSpan(
        boardKey: String,
        itemKey: String,
        fallback: ContainerSpan
    ) -> ContainerSpan {
        state(boardKey: boardKey, itemKey: itemKey)?.span ?? fallback
    }

    func upsertSpan(
        boardKey: String,
        itemKey: String,
        targetType: String,
        targetID: UUID,
        span: ContainerSpan
    ) {
        if let existing = state(boardKey: boardKey, itemKey: itemKey) {
            existing.targetType = targetType
            existing.targetID = targetID
            existing.setSpan(span)
            return
        }

        let created = CompositionItemState(
            boardKey: boardKey,
            itemKey: itemKey,
            targetType: targetType,
            targetID: targetID,
            widthColumns: span.widthColumns,
            heightUnits: span.heightUnits
        )
        modelContext.insert(created)
    }
}
