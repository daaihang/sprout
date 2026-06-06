import Foundation

enum HomeBoardMoveDirection: Sendable {
    case earlier
    case later
}

struct HomeBoardOrderUpdate: Hashable, Sendable {
    let item: HomeBoardItemSnapshot
    let sortIndex: Double
}

struct HomeBoardOrdering: Sendable {
    static let sortIndexStride = 10.0

    static func updatesForMove(
        items: [HomeBoardItemSnapshot],
        moving item: HomeBoardItemSnapshot,
        direction: HomeBoardMoveDirection
    ) -> [HomeBoardOrderUpdate] {
        guard let currentIndex = items.firstIndex(where: { $0.compositionItem.itemKey == item.compositionItem.itemKey }) else {
            return []
        }

        let targetIndex: Int
        switch direction {
        case .earlier:
            guard currentIndex > items.startIndex else { return [] }
            targetIndex = items.index(before: currentIndex)
        case .later:
            guard currentIndex < items.index(before: items.endIndex) else { return [] }
            targetIndex = items.index(after: currentIndex)
        }

        var reordered = items
        let moved = reordered.remove(at: currentIndex)
        reordered.insert(moved, at: targetIndex)
        return normalizedUpdates(for: reordered)
    }

    static func canMove(
        item: HomeBoardItemSnapshot,
        in items: [HomeBoardItemSnapshot],
        direction: HomeBoardMoveDirection
    ) -> Bool {
        guard let currentIndex = items.firstIndex(where: { $0.compositionItem.itemKey == item.compositionItem.itemKey }) else {
            return false
        }
        switch direction {
        case .earlier:
            return currentIndex > items.startIndex
        case .later:
            return currentIndex < items.index(before: items.endIndex)
        }
    }

    static func normalizedUpdates(for items: [HomeBoardItemSnapshot]) -> [HomeBoardOrderUpdate] {
        items.enumerated().map { index, item in
            HomeBoardOrderUpdate(
                item: item,
                sortIndex: Double(index + 1) * sortIndexStride
            )
        }
    }
}
