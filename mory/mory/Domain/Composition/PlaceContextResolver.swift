import Foundation

struct PlaceContextEntry: Hashable, Sendable {
    let artifact: Artifact
    let recordID: UUID
}

struct PlaceContextCluster: Hashable, Sendable {
    var entries: [PlaceContextEntry]

    var recordIDs: [UUID] {
        Array(Set(entries.map(\.recordID)))
    }

    var displayTitle: String {
        entries
            .map(\.artifact)
            .sorted { lhs, rhs in
                if lhs.title.count == rhs.title.count {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.title.count < rhs.title.count
            }
            .first?
            .title
            .trimmedOrNil
            ?? entries.first?.artifact.summary.trimmedOrNil
            ?? String(localized: "home.board.cluster.title")
    }

    var stableKey: String {
        if let coordinate = centroid {
            let latitudeBucket = Int((coordinate.latitude * 1_000).rounded())
            let longitudeBucket = Int((coordinate.longitude * 1_000).rounded())
            return "location-\(latitudeBucket)-\(longitudeBucket)-\(PlaceContextResolver.normalizedName(displayTitle))"
        }
        return "location-\(PlaceContextResolver.normalizedName(displayTitle))"
    }

    private var centroid: PlaceCoordinate? {
        let coordinates = entries.compactMap { PlaceContextResolver.coordinate(for: $0.artifact) }
        guard !coordinates.isEmpty else { return nil }
        let latitude = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
        let longitude = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
        return PlaceCoordinate(latitude: latitude, longitude: longitude)
    }
}

struct PlaceContextResolver: Sendable {
    private static let sameCoordinateRadiusMeters = 120.0
    private static let relatedNameRadiusMeters = 420.0
    private static let hardSplitDistanceMeters = 900.0
    private static let relatedNameThreshold = 0.48
    private static let strongNameThreshold = 0.82

    func clusters(from entries: [PlaceContextEntry]) -> [PlaceContextCluster] {
        var clusters: [PlaceContextCluster] = []

        for entry in entries where entry.artifact.kind == .location {
            if let index = clusters.firstIndex(where: { cluster in
                cluster.entries.contains { existing in
                    Self.isSamePlace(entry.artifact, existing.artifact)
                }
            }) {
                clusters[index].entries.append(entry)
            } else {
                clusters.append(PlaceContextCluster(entries: [entry]))
            }
        }

        return clusters
    }

    static func isSamePlace(_ lhs: Artifact, _ rhs: Artifact) -> Bool {
        let lhsName = normalizedName(lhs.title.trimmedOrNil ?? lhs.summary)
        let rhsName = normalizedName(rhs.title.trimmedOrNil ?? rhs.summary)
        let nameScore = similarity(lhsName, rhsName)
        let lhsCoordinate = coordinate(for: lhs)
        let rhsCoordinate = coordinate(for: rhs)

        if let lhsCoordinate, let rhsCoordinate {
            let distance = lhsCoordinate.distance(to: rhsCoordinate)
            if distance <= sameCoordinateRadiusMeters {
                return true
            }
            if distance >= hardSplitDistanceMeters {
                return false
            }
            return distance <= relatedNameRadiusMeters && nameScore >= relatedNameThreshold
        }

        return nameScore >= strongNameThreshold
    }

    static func coordinate(for artifact: Artifact) -> PlaceCoordinate? {
        guard
            let latitude = artifact.metadata["latitude"].flatMap(Double.init),
            let longitude = artifact.metadata["longitude"].flatMap(Double.init)
        else {
            return nil
        }
        return PlaceCoordinate(latitude: latitude, longitude: longitude)
    }

    static func normalizedName(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func similarity(_ lhs: String, _ rhs: String) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        if lhs == rhs { return 1 }
        if lhs.count >= 3, rhs.count >= 3, (lhs.contains(rhs) || rhs.contains(lhs)) {
            return 0.86
        }

        let lhsBigrams = Set(bigrams(lhs))
        let rhsBigrams = Set(bigrams(rhs))
        guard !lhsBigrams.isEmpty, !rhsBigrams.isEmpty else { return 0 }
        let intersection = lhsBigrams.intersection(rhsBigrams).count
        return (2.0 * Double(intersection)) / Double(lhsBigrams.count + rhsBigrams.count)
    }

    private static func bigrams(_ value: String) -> [String] {
        let characters = Array(value)
        guard characters.count >= 2 else { return characters.map(String.init) }
        return characters.indices.dropLast().map { index in
            String(characters[index]) + String(characters[characters.index(after: index)])
        }
    }
}

struct PlaceCoordinate: Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    func distance(to other: PlaceCoordinate) -> Double {
        let earthRadiusMeters = 6_371_000.0
        let lhsLatitude = latitude * .pi / 180
        let rhsLatitude = other.latitude * .pi / 180
        let deltaLatitude = (other.latitude - latitude) * .pi / 180
        let deltaLongitude = (other.longitude - longitude) * .pi / 180

        let haversine = sin(deltaLatitude / 2) * sin(deltaLatitude / 2)
            + cos(lhsLatitude) * cos(rhsLatitude) * sin(deltaLongitude / 2) * sin(deltaLongitude / 2)
        let angularDistance = 2 * atan2(sqrt(haversine), sqrt(1 - haversine))
        return earthRadiusMeters * angularDistance
    }
}
