import Foundation
import SwiftData

struct HomeBoardStoreBuilder: Sendable {

    func fetchHomeBoard(
        date: Date,
        limit: Int,
        modelContext: ModelContext,
        graphContext: MemoryGraphContext,
        memories: [MemorySummary]
    ) throws -> HomeBoardSnapshot {
        let now = Date.now
        let boardID = UUID()
        let compositionID = UUID()

        let board = Board(
            id: boardID,
            boardKey: "home-board",
            kind: .homeDay,
            title: "Today",
            subtitle: date.formatted(date: .abbreviated, time: .omitted),
            boardDate: date,
            createdAt: now,
            updatedAt: now
        )

        let composition = Composition(
            id: compositionID,
            boardID: boardID,
            compositionKey: "home-composition",
            title: "Home Grid",
            sortOrder: 0,
            createdAt: now,
            updatedAt: now
        )

        let itemLimit = min(max(limit, 0), 8)
        var items: [HomeBoardItemSnapshot] = []

        func appendItem(
            itemKey: String,
            targetType: CompositionTargetType,
            targetID: UUID,
            renderValue: CompositionRenderValue
        ) {
            guard items.count < itemLimit else { return }
            let item = CompositionItem(
                id: UUID(),
                boardID: boardID,
                boardKey: board.boardKey,
                compositionID: compositionID,
                compositionKey: composition.compositionKey,
                itemKey: itemKey,
                targetType: targetType,
                targetID: targetID,
                widthColumns: 2,
                heightUnits: 1,
                zIndex: items.count,
                rotationDegrees: rotationForPosition(items.count),
                scale: 1.0,
                isHidden: false,
                updatedAt: now
            )
            items.append(
                HomeBoardItemSnapshot(
                    compositionItem: item,
                    renderValue: renderValue
                )
            )
        }

        let memoriesToShow = memories
            .sorted { $0.record.updatedAt > $1.record.updatedAt }
            .prefix(3)
        for memory in memoriesToShow {
            appendItem(
                itemKey: "memory-\(memory.id)",
                targetType: .record,
                targetID: memory.id,
                renderValue: .memory(memory)
            )
        }

        let acceptedArcs = graphContext.arcs
            .filter { $0.status == .accepted }
            .sorted { $0.updatedAt > $1.updatedAt }
        for arc in acceptedArcs {
            appendItem(
                itemKey: "arc-\(arc.id)",
                targetType: .arc,
                targetID: arc.id,
                renderValue: .arc(arc)
            )
        }

        let suggestedReflections = graphContext.reflections
            .filter { $0.status == .suggested }
            .sorted { $0.createdAt > $1.createdAt }
        for reflection in suggestedReflections {
            appendItem(
                itemKey: "reflection-\(reflection.id)",
                targetType: .reflection,
                targetID: reflection.id,
                renderValue: .reflection(reflection)
            )
        }

        if memories.count < 3 {
            appendItem(
                itemKey: "home-onboarding",
                targetType: .system,
                targetID: boardID,
                renderValue: .system(
                    title: "Welcome to Mory",
                    subtitle: "Record your first memories. Storylines and reflections will appear here."
                )
            )
        }

        return HomeBoardSnapshot(
            board: board,
            composition: composition,
            items: items
        )
    }

    private func rotationForPosition(_ index: Int) -> Double {
        let rotations: [Double] = [0, -1.5, 1.2, -0.8, 1.5, -1.0, 0.5, -1.2]
        return rotations[index % rotations.count]
    }
}
