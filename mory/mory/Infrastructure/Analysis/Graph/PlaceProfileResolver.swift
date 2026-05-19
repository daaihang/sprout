import Foundation

struct PlaceProfileResolutionResult: Sendable {
    var profiles: [PlaceProfile]
    var entityNodes: [EntityNode]
    var artifactEntityLinks: [ArtifactEntityLink]
}

struct PlaceProfileResolver: Sendable {
    func resolve(
        locationArtifacts: [Artifact],
        recordID: UUID,
        existingProfiles: [PlaceProfile],
        existingEntityNodes: [EntityNode],
        existingArtifactEntityLinks: [ArtifactEntityLink],
        timestamp: Date
    ) -> PlaceProfileResolutionResult {
        var profiles = existingProfiles
        var entityNodes = existingEntityNodes
        var links = existingArtifactEntityLinks

        for artifact in locationArtifacts where artifact.kind == .location {
            let profileIndex = matchingProfileIndex(for: artifact, in: profiles)
            let profile: PlaceProfile
            if let profileIndex {
                profiles[profileIndex] = updatedProfile(profiles[profileIndex], with: artifact, recordID: recordID, timestamp: timestamp)
                profile = profiles[profileIndex]
            } else {
                profile = makeProfile(from: artifact, recordID: recordID, existingEntityNodes: entityNodes, timestamp: timestamp)
                profiles.append(profile)
            }

            upsertEntityNode(for: profile, artifact: artifact, recordID: recordID, timestamp: timestamp, into: &entityNodes)
            upsertArtifactLink(for: artifact, profile: profile, recordID: recordID, timestamp: timestamp, into: &links)
        }

        return PlaceProfileResolutionResult(
            profiles: profiles,
            entityNodes: entityNodes,
            artifactEntityLinks: links
        )
    }

    private func matchingProfileIndex(for artifact: Artifact, in profiles: [PlaceProfile]) -> Int? {
        profiles.firstIndex { profile in
            PlaceContextResolver.isSamePlace(artifact, profileArtifact(for: profile, fallbackRecordID: artifact.recordID))
        }
    }

    private func makeProfile(
        from artifact: Artifact,
        recordID: UUID,
        existingEntityNodes: [EntityNode],
        timestamp: Date
    ) -> PlaceProfile {
        let name = preferredName(for: artifact)
        let coordinate = PlaceContextResolver.coordinate(for: artifact)
        let matchedEntity = coordinate == nil ? existingEntityNodes.first { node in
            guard node.kind == .place else { return false }
            return PlaceContextResolver.isSamePlace(artifact, profileArtifact(for: node, fallbackRecordID: recordID, timestamp: timestamp))
        } : nil
        let entityID = matchedEntity?.id ?? UUID()
        return PlaceProfile(
            entityID: entityID,
            displayName: matchedEntity?.displayName.trimmedOrNil ?? name,
            canonicalName: matchedEntity?.canonicalName.trimmedOrNil ?? name,
            aliases: normalizedAliases([artifact.title, artifact.summary, matchedEntity?.displayName, matchedEntity?.canonicalName] + (matchedEntity?.aliases ?? [])),
            centroidLatitude: coordinate?.latitude,
            centroidLongitude: coordinate?.longitude,
            radiusMeters: coordinate == nil ? 0 : 120,
            mentionCount: 1,
            sourceArtifactIDs: [artifact.id],
            sourceRecordIDs: [recordID],
            confirmationState: .inferred,
            confidence: coordinate == nil ? 0.62 : 0.78,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private func updatedProfile(_ profile: PlaceProfile, with artifact: Artifact, recordID: UUID, timestamp: Date) -> PlaceProfile {
        var updated = profile
        let coordinate = PlaceContextResolver.coordinate(for: artifact)
        let previousMentionCount = max(updated.mentionCount, 1)
        let incomingName = preferredName(for: artifact)
        let isNewArtifact = !updated.sourceArtifactIDs.contains(artifact.id)

        if let coordinate, isNewArtifact {
            if let currentLatitude = updated.centroidLatitude, let currentLongitude = updated.centroidLongitude {
                let current = PlaceCoordinate(latitude: currentLatitude, longitude: currentLongitude)
                let distance = current.distance(to: coordinate)
                updated.centroidLatitude = ((currentLatitude * Double(previousMentionCount)) + coordinate.latitude) / Double(previousMentionCount + 1)
                updated.centroidLongitude = ((currentLongitude * Double(previousMentionCount)) + coordinate.longitude) / Double(previousMentionCount + 1)
                updated.radiusMeters = max(updated.radiusMeters, min(distance + 60, 900))
            } else {
                updated.centroidLatitude = coordinate.latitude
                updated.centroidLongitude = coordinate.longitude
                updated.radiusMeters = max(updated.radiusMeters, 120)
            }
        }

        if updated.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || updated.displayName == "Location" {
            updated.displayName = incomingName
        }
        if updated.canonicalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || updated.canonicalName == "Location" {
            updated.canonicalName = incomingName
        }
        updated.aliases = normalizedAliases(updated.aliases + [artifact.title, artifact.summary, incomingName])
        if isNewArtifact {
            updated.mentionCount += 1
        }
        updated.sourceArtifactIDs = mergeUniqueIDs(updated.sourceArtifactIDs, [artifact.id])
        updated.sourceRecordIDs = mergeUniqueIDs(updated.sourceRecordIDs, [recordID])
        updated.confidence = max(updated.confidence ?? 0, coordinate == nil ? 0.62 : 0.78)
        updated.updatedAt = timestamp
        return updated
    }

    private func upsertEntityNode(
        for profile: PlaceProfile,
        artifact: Artifact,
        recordID: UUID,
        timestamp: Date,
        into entityNodes: inout [EntityNode]
    ) {
        if let index = entityNodes.firstIndex(where: { $0.id == profile.entityID }) {
            entityNodes[index].displayName = profile.displayName
            entityNodes[index].canonicalName = profile.canonicalName
            entityNodes[index].aliases = normalizedAliases(entityNodes[index].aliases + profile.aliases + [artifact.title, artifact.summary])
            entityNodes[index].provenanceRecordIDs = mergeUniqueIDs(entityNodes[index].provenanceRecordIDs, [recordID])
            entityNodes[index].confidence = max(entityNodes[index].confidence ?? 0, profile.confidence ?? 0)
            entityNodes[index].updatedAt = timestamp
        } else {
            entityNodes.append(EntityNode(
                id: profile.entityID,
                kind: .place,
                displayName: profile.displayName,
                canonicalName: profile.canonicalName,
                aliases: profile.aliases,
                summary: coordinateSummary(for: profile),
                provenanceRecordIDs: [recordID],
                createdAt: profile.createdAt,
                updatedAt: timestamp,
                confidence: profile.confidence
            ))
        }
    }

    private func upsertArtifactLink(
        for artifact: Artifact,
        profile: PlaceProfile,
        recordID: UUID,
        timestamp: Date,
        into links: inout [ArtifactEntityLink]
    ) {
        let evidence = "Matched place profile: \(profile.canonicalName)"
        if let index = links.firstIndex(where: { $0.artifactID == artifact.id && $0.entityID == profile.entityID }) {
            links[index].confidence = max(links[index].confidence ?? 0, profile.confidence ?? 0)
            links[index].source = "placeProfile"
            links[index].sourceRecordID = recordID
            links[index].evidenceSummary = evidence
            return
        }
        links.append(ArtifactEntityLink(
            artifactID: artifact.id,
            entityID: profile.entityID,
            confidence: profile.confidence,
            source: "placeProfile",
            sourceRecordID: recordID,
            evidenceSummary: evidence,
            createdAt: timestamp
        ))
    }

    private func profileArtifact(for profile: PlaceProfile, fallbackRecordID: UUID) -> Artifact {
        var metadata: [String: String] = [:]
        if let latitude = profile.centroidLatitude { metadata["latitude"] = String(latitude) }
        if let longitude = profile.centroidLongitude { metadata["longitude"] = String(longitude) }
        return Artifact(
            recordID: fallbackRecordID,
            kind: .location,
            title: profile.displayName,
            summary: profile.canonicalName,
            textContent: profile.canonicalName,
            payload: .metadata(metadata),
            metadata: metadata,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt
        )
    }

    private func profileArtifact(for node: EntityNode, fallbackRecordID: UUID, timestamp: Date) -> Artifact {
        Artifact(
            recordID: fallbackRecordID,
            kind: .location,
            title: node.displayName,
            summary: node.canonicalName,
            textContent: node.canonicalName,
            payload: .metadata([:]),
            metadata: [:],
            createdAt: node.createdAt,
            updatedAt: timestamp
        )
    }

    private func preferredName(for artifact: Artifact) -> String {
        artifact.title.trimmedOrNil
            ?? artifact.summary.trimmedOrNil
            ?? "Location"
    }

    private func coordinateSummary(for profile: PlaceProfile) -> String {
        guard let latitude = profile.centroidLatitude, let longitude = profile.centroidLongitude else {
            return profile.canonicalName
        }
        return "\(profile.canonicalName) · \(String(format: "%.5f", latitude)), \(String(format: "%.5f", longitude))"
    }

    private func normalizedAliases(_ values: [String?]) -> [String] {
        var seen = Set<String>()
        var aliases: [String] = []
        for value in values {
            guard let trimmed = value?.trimmedOrNil else { continue }
            let key = PlaceContextResolver.normalizedName(trimmed)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            aliases.append(trimmed)
        }
        return aliases
    }

    private func mergeUniqueIDs(_ lhs: [UUID], _ rhs: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        var result: [UUID] = []
        for id in lhs + rhs where !seen.contains(id) {
            seen.insert(id)
            result.append(id)
        }
        return result
    }
}
