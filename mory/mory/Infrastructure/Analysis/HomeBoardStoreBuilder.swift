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

        var items: [HomeBoardItemSnapshot] = []
        var zIndex = 0

        // Add recent memories as composition items
        let memoriesToShow = Array(memories.prefix(limit))
        for (index, memory) in memoriesToShow.enumerated() {
            let item = CompositionItem(
                id: UUID(),
                boardID: boardID,
                boardKey: board.boardKey,
                compositionID: compositionID,
                compositionKey: composition.compositionKey,
                itemKey: "memory-\(memory.id)",
                targetType: .record,
                targetID: memory.id,
                widthColumns: 2,
                heightUnits: 1,
                zIndex: zIndex,
                rotationDegrees: rotationForPosition(index),
                scale: 1.0,
                isHidden: false,
                updatedAt: now
            )
            let homeItem = HomeBoardItemSnapshot(
                compositionItem: item,
                renderValue: .memory(memory)
            )
            items.append(homeItem)
            zIndex += 1
        }

        // Add accepted arcs from graph context
        let acceptedArcs = graphContext.arcs.filter { $0.status == .accepted }
        for (index, arc) in acceptedArcs.prefix(4).enumerated() {
            let item = CompositionItem(
                id: UUID(),
                boardID: boardID,
                boardKey: board.boardKey,
                compositionID: compositionID,
                compositionKey: composition.compositionKey,
                itemKey: "arc-\(arc.id)",
                targetType: .arc,
                targetID: arc.id,
                widthColumns: 2,
                heightUnits: 1,
                zIndex: zIndex,
                rotationDegrees: rotationForPosition(memoriesToShow.count + index),
                scale: 1.0,
                isHidden: false,
                updatedAt: now
            )
            let homeItem = HomeBoardItemSnapshot(
                compositionItem: item,
                renderValue: .arc(arc)
            )
            items.append(homeItem)
            zIndex += 1
        }

        // Add saved reflections from graph context
        let savedReflections = graphContext.reflections.filter { $0.status == .saved }
        for (index, reflection) in savedReflections.prefix(4).enumerated() {
            let item = CompositionItem(
                id: UUID(),
                boardID: boardID,
                boardKey: board.boardKey,
                compositionID: compositionID,
                compositionKey: composition.compositionKey,
                itemKey: "reflection-\(reflection.id)",
                targetType: .reflection,
                targetID: reflection.id,
                widthColumns: 2,
                heightUnits: 1,
                zIndex: zIndex,
                rotationDegrees: rotationForPosition(memoriesToShow.count + acceptedArcs.count + index),
                scale: 1.0,
                isHidden: false,
                updatedAt: now
            )
            let homeItem = HomeBoardItemSnapshot(
                compositionItem: item,
                renderValue: .reflection(reflection)
            )
            items.append(homeItem)
            zIndex += 1
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