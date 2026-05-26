import Foundation

nonisolated enum OrderedCollections {
    static func unique<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        var result: [T] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }

    static func stableUnion<T: Hashable>(_ lhs: [T], _ rhs: [T]) -> [T] {
        unique(lhs + rhs)
    }
}
