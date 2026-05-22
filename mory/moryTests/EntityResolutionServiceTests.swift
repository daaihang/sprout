import XCTest
@testable import mory

final class EntityResolutionServiceTests: XCTestCase {
    func testResolveBuildsSamePersonCandidateAndMergeProposal() async throws {
        let alexID = UUID()
        let alexanderID = UUID()
        let service = DefaultEntityResolutionService()
        let context = EntityResolutionContext(
            selfProfile: SelfProfile(displayName: "Me"),
            existingProfiles: [
                EntityProfile(
                    entityID: alexID,
                    kind: .person,
                    displayName: "Alex",
                    aliases: ["A. Chen"],
                    mentionCount: 8,
                    confirmationState: .userConfirmed
                ),
                EntityProfile(
                    entityID: alexanderID,
                    kind: .person,
                    displayName: "Alexander Chen",
                    aliases: ["Alex Chen"],
                    mentionCount: 2
                ),
            ]
        )
        let mentions = [
            EntityMention(kind: .person, value: "Alexander Chen", hintedEntityID: alexID),
        ]

        let result = try await service.resolve(mentions: mentions, context: context)

        XCTAssertTrue(result.links.contains { $0.kind == .samePersonCandidate })
        let merge = try XCTUnwrap(result.mergeProposals.first)
        XCTAssertEqual(Set([merge.primaryEntityID, merge.mergingEntityID]), Set([alexID, alexanderID]))
    }

    func testResolveHonorsNotSameCorrectionEvidence() async throws {
        let alexID = UUID()
        let alexanderID = UUID()
        let service = DefaultEntityResolutionService()
        let context = EntityResolutionContext(
            selfProfile: SelfProfile(displayName: "Me"),
            existingProfiles: [
                EntityProfile(entityID: alexanderID, kind: .person, displayName: "Alexander Chen", aliases: ["Alex"]),
            ],
            correctionEvents: [
                CorrectionEvent(
                    kind: .notSameEntity,
                    actor: .user,
                    targetEntityIDs: [alexID, alexanderID],
                    note: "Different Alex"
                ),
            ]
        )
        let mentions = [
            EntityMention(kind: .person, value: "Alex", hintedEntityID: alexID),
        ]

        let result = try await service.resolve(mentions: mentions, context: context)

        XCTAssertTrue(result.mergeProposals.isEmpty)
        XCTAssertTrue(result.links.contains { $0.kind == .notSameDecision && $0.resolvedEntityID == alexID })
    }

    func testResolveHonorsNotSameCorrectionEvidenceWithoutHintedEntity() async throws {
        let alexID = UUID()
        let alexanderID = UUID()
        let service = DefaultEntityResolutionService()
        let context = EntityResolutionContext(
            selfProfile: SelfProfile(displayName: "Me"),
            existingProfiles: [
                EntityProfile(entityID: alexID, kind: .person, displayName: "Alex Johnson"),
                EntityProfile(entityID: alexanderID, kind: .person, displayName: "Alexander Chen", aliases: ["Alex"]),
            ],
            correctionEvents: [
                CorrectionEvent(
                    kind: .notSameEntity,
                    actor: .user,
                    targetEntityIDs: [alexID, alexanderID],
                    note: "Different Alex"
                ),
            ]
        )
        let mentions = [
            EntityMention(kind: .person, value: "Alex"),
        ]

        let result = try await service.resolve(mentions: mentions, context: context)

        XCTAssertTrue(result.mergeProposals.isEmpty)
        XCTAssertTrue(result.links.contains { $0.kind == .notSameDecision && $0.resolvedEntityID == nil })
        XCTAssertTrue(result.ambiguousBuckets.contains { Set($0.candidateEntityIDs) == Set([alexID, alexanderID]) })
    }

    func testResolveMatchesChinesePersonNameExactly() async throws {
        let zhangID = UUID()
        let service = DefaultEntityResolutionService()
        let context = EntityResolutionContext(
            selfProfile: SelfProfile(displayName: "Me"),
            existingProfiles: [
                EntityProfile(entityID: zhangID, kind: .person, displayName: "张伟", mentionCount: 1),
            ]
        )
        let mentions = [
            EntityMention(kind: .person, value: "张伟"),
        ]

        let result = try await service.resolve(mentions: mentions, context: context)

        XCTAssertTrue(result.links.contains {
            $0.kind == .resolvedEntity && $0.resolvedEntityID == zhangID && $0.confidence >= 0.98
        })
    }

    func testResolveBuildsRoleLabelAmbiguousBucket() async throws {
        let service = DefaultEntityResolutionService()
        let context = EntityResolutionContext(
            selfProfile: SelfProfile(displayName: "Me"),
            existingProfiles: [
                EntityProfile(entityID: UUID(), kind: .person, displayName: "Lily", relationshipToUser: .friend),
                EntityProfile(entityID: UUID(), kind: .person, displayName: "Max", relationshipToUser: .friend),
            ]
        )
        let mentions = [
            EntityMention(kind: .person, value: "舍友"),
        ]

        let result = try await service.resolve(mentions: mentions, context: context)

        XCTAssertTrue(result.links.contains { $0.kind == .ambiguousEntityBucket })
        let bucket = try XCTUnwrap(result.ambiguousBuckets.first)
        XCTAssertEqual(bucket.label, "舍友")
        XCTAssertGreaterThanOrEqual(bucket.candidateEntityIDs.count, 1)
    }
}
