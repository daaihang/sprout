import Foundation

struct MoryBoardGridPoint: Codable, Hashable, Sendable {
    var x: Int
    var y: Int

    init(x: Int, y: Int) {
        self.x = max(0, x)
        self.y = max(0, y)
    }
}

struct MoryBoardGridSize: Codable, Hashable, Sendable {
    static let stamp = MoryBoardGridSize(width: 1, height: 1)
    static let strip = MoryBoardGridSize(width: 2, height: 1)
    static let card = MoryBoardGridSize(width: 2, height: 2)
    static let allowedSizes: [MoryBoardGridSize] = [.stamp, .strip, .card]

    var w: Int
    var h: Int

    init(width: Int, height: Int) {
        if width >= 2, height >= 2 {
            self.w = 2
            self.h = 2
        } else if width >= 2 {
            self.w = 2
            self.h = 1
        } else {
            self.w = 1
            self.h = 1
        }
    }
}

struct MoryBoardLayoutItem<ID: Hashable & Sendable>: Hashable, Sendable {
    var id: ID
    var x: Int
    var y: Int
    var w: Int
    var h: Int
    var zIndex: Int
    var isPinned: Bool
    var isUserAdjusted: Bool

    init(
        id: ID,
        x: Int,
        y: Int,
        w: Int,
        h: Int,
        zIndex: Int = 0,
        isPinned: Bool = false,
        isUserAdjusted: Bool = false
    ) {
        let size = MoryBoardGridSize(width: w, height: h)
        self.id = id
        self.x = max(0, x)
        self.y = max(0, y)
        self.w = size.w
        self.h = size.h
        self.zIndex = zIndex
        self.isPinned = isPinned
        self.isUserAdjusted = isUserAdjusted
    }

    init(
        id: ID,
        point: MoryBoardGridPoint,
        size: MoryBoardGridSize,
        zIndex: Int = 0,
        isPinned: Bool = false,
        isUserAdjusted: Bool = false
    ) {
        self.init(
            id: id,
            x: point.x,
            y: point.y,
            w: size.w,
            h: size.h,
            zIndex: zIndex,
            isPinned: isPinned,
            isUserAdjusted: isUserAdjusted
        )
    }

    var point: MoryBoardGridPoint {
        get { MoryBoardGridPoint(x: x, y: y) }
        set {
            x = max(0, newValue.x)
            y = max(0, newValue.y)
        }
    }

    var size: MoryBoardGridSize {
        get { MoryBoardGridSize(width: w, height: h) }
        set {
            w = newValue.w
            h = newValue.h
        }
    }
}

extension MoryBoardLayoutItem: Codable where ID: Codable {}

struct MoryBoardLayoutEngine<ID: Hashable & Sendable>: Sendable {
    let columns: Int

    init(columns: Int = 4) {
        self.columns = max(1, columns)
    }

    func placeNewItem(
        _ item: MoryBoardLayoutItem<ID>,
        in items: [MoryBoardLayoutItem<ID>]
    ) -> [MoryBoardLayoutItem<ID>] {
        var next = normalized(items)
        var item = normalized(item)
        item.zIndex = (next.map(\.zIndex).max() ?? -1) + 1
        item.point = firstAvailablePlacement(for: item, in: next, from: MoryBoardGridPoint(x: 0, y: 0))
        next.append(item)
        return next
    }

    func moveItem(
        id: ID,
        to target: MoryBoardGridPoint,
        in items: [MoryBoardLayoutItem<ID>]
    ) -> [MoryBoardLayoutItem<ID>] {
        var next = normalized(items)
        guard let index = next.firstIndex(where: { $0.id == id }) else { return next }
        next[index].point = clamped(target, for: next[index])
        return resolvingCollisions(in: next, activeID: id)
    }

    func resizeItem(
        id: ID,
        to size: MoryBoardGridSize,
        in items: [MoryBoardLayoutItem<ID>]
    ) -> [MoryBoardLayoutItem<ID>] {
        var next = normalized(items)
        guard let index = next.firstIndex(where: { $0.id == id }) else { return next }
        next[index].size = size
        next[index].point = clamped(next[index].point, for: next[index])
        next = resolvingCollisions(in: next, activeID: id)
        return compactVertically(next)
    }

    func autoPack(_ items: [MoryBoardLayoutItem<ID>]) -> [MoryBoardLayoutItem<ID>] {
        var placed: [MoryBoardLayoutItem<ID>] = []
        for item in normalized(items) {
            var item = item
            item.point = firstAvailablePlacement(for: item, in: placed, from: MoryBoardGridPoint(x: 0, y: 0))
            placed.append(item)
        }
        return placed
    }

    func compactVertically(_ items: [MoryBoardLayoutItem<ID>]) -> [MoryBoardLayoutItem<ID>] {
        var next = normalized(items)
        let orderedIDs = next
            .sorted {
                if $0.y == $1.y {
                    if $0.x == $1.x { return $0.zIndex < $1.zIndex }
                    return $0.x < $1.x
                }
                return $0.y < $1.y
            }
            .map(\.id)

        for id in orderedIDs {
            guard let index = next.firstIndex(where: { $0.id == id }), !next[index].isPinned else {
                continue
            }
            while next[index].y > 0 {
                var candidate = next[index]
                candidate.y -= 1
                guard canPlace(candidate, in: next, excluding: candidate.id) else {
                    break
                }
                next[index] = candidate
            }
        }
        return next
    }

    func hasOverlaps(_ items: [MoryBoardLayoutItem<ID>]) -> Bool {
        let items = normalized(items)
        for lhsIndex in items.indices {
            for rhsIndex in items.indices where rhsIndex > lhsIndex {
                if collides(items[lhsIndex], items[rhsIndex]) {
                    return true
                }
            }
        }
        return false
    }

    func collides(_ lhs: MoryBoardLayoutItem<ID>, _ rhs: MoryBoardLayoutItem<ID>) -> Bool {
        guard lhs.id != rhs.id else { return false }
        if lhs.x + lhs.w <= rhs.x { return false }
        if rhs.x + rhs.w <= lhs.x { return false }
        if lhs.y + lhs.h <= rhs.y { return false }
        if rhs.y + rhs.h <= lhs.y { return false }
        return true
    }

    private func resolvingCollisions(
        in items: [MoryBoardLayoutItem<ID>],
        activeID: ID,
        depth: Int = 0
    ) -> [MoryBoardLayoutItem<ID>] {
        guard depth < max(16, items.count * items.count * 4) else {
            return autoPack(items)
        }
        var next = normalized(items)
        guard let activeIndex = next.firstIndex(where: { $0.id == activeID }) else { return next }

        while let collisionIndex = firstCollisionIndex(for: next[activeIndex], in: next) {
            let collision = next[collisionIndex]
            if collision.isPinned {
                let fallback = firstAvailablePlacement(
                    for: next[activeIndex],
                    in: next,
                    from: next[activeIndex].point,
                    excluding: activeID
                )
                next[activeIndex].point = fallback
                return resolvingCollisions(in: next, activeID: activeID, depth: depth + 1)
            }

            next = pushingAway(
                itemID: collision.id,
                blockerID: activeID,
                in: next,
                depth: depth + 1
            )
            guard next.indices.contains(activeIndex) else { return next }
        }
        return next
    }

    private func pushingAway(
        itemID: ID,
        blockerID: ID,
        in items: [MoryBoardLayoutItem<ID>],
        depth: Int
    ) -> [MoryBoardLayoutItem<ID>] {
        var next = items
        guard let itemIndex = next.firstIndex(where: { $0.id == itemID }),
              let blocker = next.first(where: { $0.id == blockerID })
        else {
            return next
        }

        let item = next[itemIndex]
        if let sidePlacement = sidePlacement(for: item, in: next) {
            next[itemIndex].point = sidePlacement
        } else {
            next[itemIndex].point = clamped(
                MoryBoardGridPoint(x: item.x, y: blocker.y + blocker.h),
                for: item
            )
        }
        return resolvingCollisions(in: next, activeID: itemID, depth: depth + 1)
    }

    private func sidePlacement(
        for item: MoryBoardLayoutItem<ID>,
        in items: [MoryBoardLayoutItem<ID>]
    ) -> MoryBoardGridPoint? {
        let maxX = max(0, columns - item.w)
        let offsets = (1...max(1, columns)).flatMap { [$0, -$0] }
        for offset in offsets {
            let x = item.x + offset
            guard x >= 0, x <= maxX else { continue }
            let point = MoryBoardGridPoint(x: x, y: item.y)
            var candidate = item
            candidate.point = point
            if canPlace(candidate, in: items, excluding: item.id) {
                return point
            }
        }
        return nil
    }

    private func firstCollisionIndex(
        for item: MoryBoardLayoutItem<ID>,
        in items: [MoryBoardLayoutItem<ID>]
    ) -> Array<MoryBoardLayoutItem<ID>>.Index? {
        items.indices
            .filter { items[$0].id != item.id && collides(item, items[$0]) }
            .sorted {
                let lhs = items[$0]
                let rhs = items[$1]
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
                if lhs.y == rhs.y {
                    if lhs.x == rhs.x { return lhs.zIndex < rhs.zIndex }
                    return lhs.x < rhs.x
                }
                return lhs.y < rhs.y
            }
            .first
    }

    private func firstAvailablePlacement(
        for item: MoryBoardLayoutItem<ID>,
        in items: [MoryBoardLayoutItem<ID>],
        from start: MoryBoardGridPoint,
        excluding excludedID: ID? = nil
    ) -> MoryBoardGridPoint {
        let maxX = max(0, columns - item.w)
        var row = max(0, start.y)
        var firstRow = true

        while true {
            let columnsToTry: [Int]
            if firstRow {
                let startX = min(max(0, start.x), maxX)
                columnsToTry = (0...maxX).sorted {
                    abs($0 - startX) == abs($1 - startX) ? $0 < $1 : abs($0 - startX) < abs($1 - startX)
                }
            } else {
                columnsToTry = Array(0...maxX)
            }

            for column in columnsToTry {
                var candidate = item
                candidate.point = MoryBoardGridPoint(x: column, y: row)
                if canPlace(candidate, in: items, excluding: excludedID ?? item.id) {
                    return candidate.point
                }
            }

            row += 1
            firstRow = false
        }
    }

    private func canPlace(
        _ candidate: MoryBoardLayoutItem<ID>,
        in items: [MoryBoardLayoutItem<ID>],
        excluding excludedID: ID
    ) -> Bool {
        guard candidate.x >= 0,
              candidate.y >= 0,
              candidate.x + candidate.w <= columns
        else {
            return false
        }
        return !items.contains { other in
            other.id != excludedID && collides(candidate, other)
        }
    }

    private func normalized(_ items: [MoryBoardLayoutItem<ID>]) -> [MoryBoardLayoutItem<ID>] {
        items.map(normalized(_:))
    }

    private func normalized(_ item: MoryBoardLayoutItem<ID>) -> MoryBoardLayoutItem<ID> {
        var item = item
        item.size = item.size
        item.point = clamped(item.point, for: item)
        return item
    }

    private func clamped(
        _ point: MoryBoardGridPoint,
        for item: MoryBoardLayoutItem<ID>
    ) -> MoryBoardGridPoint {
        MoryBoardGridPoint(
            x: min(max(0, point.x), max(0, columns - item.w)),
            y: max(0, point.y)
        )
    }
}
