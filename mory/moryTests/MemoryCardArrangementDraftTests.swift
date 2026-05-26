import XCTest
@testable import mory

final class MemoryCardArrangementDraftTests: XCTestCase {
    func testUnstackRestoresContentSpecificRecipesAndSizes() {
        let photoID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let videoID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let audioID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let drafts = [
            CaptureArtifactDraft(
                draftID: photoID,
                origin: .manual,
                content: .photo(PhotoArtifactContent(title: "Photo", summary: "photo", filename: "photo.jpg"))
            ),
            CaptureArtifactDraft(
                draftID: videoID,
                origin: .manual,
                content: .video(VideoArtifactContent(title: "Video", summary: "video", filename: "video.mov"))
            ),
            CaptureArtifactDraft(
                draftID: audioID,
                origin: .manual,
                content: .audio(AudioArtifactContent(title: "Audio", summary: "audio", filename: "audio.caf"))
            )
        ]

        var arrangement = MemoryCardArrangementDraft()
        drafts.forEach { arrangement.appendArtifactDraft($0) }
        arrangement.toggleStackWithPrevious(draftID: videoID)
        arrangement.toggleStackWithPrevious(draftID: audioID)

        arrangement.unstackContainingDraft(videoID, artifactDrafts: drafts)

        let nodesByDraftID = Dictionary(uniqueKeysWithValues: arrangement.nodes.compactMap { node -> (UUID, MemoryCardDraftNode)? in
            guard case let .artifactDraft(id) = node.contentRef else { return nil }
            return (id, node)
        })
        XCTAssertEqual(nodesByDraftID[photoID]?.visualRecipe, .polaroid)
        XCTAssertEqual(nodesByDraftID[photoID]?.layout.size, .hero)
        XCTAssertEqual(nodesByDraftID[videoID]?.visualRecipe, .filmFrame)
        XCTAssertEqual(nodesByDraftID[videoID]?.layout.size, .hero)
        XCTAssertEqual(nodesByDraftID[audioID]?.visualRecipe, .cassette)
        XCTAssertEqual(nodesByDraftID[audioID]?.layout.size, .wide)
    }

    func testRemovingDraftFromGroupRestoresRemainingContentRecipe() {
        let photoID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let videoID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let photoDraft = CaptureArtifactDraft(
            draftID: photoID,
            origin: .manual,
            content: .photo(PhotoArtifactContent(title: "Photo", summary: "photo", filename: "photo.jpg"))
        )
        let videoDraft = CaptureArtifactDraft(
            draftID: videoID,
            origin: .manual,
            content: .video(VideoArtifactContent(title: "Video", summary: "video", filename: "video.mov"))
        )

        var arrangement = MemoryCardArrangementDraft()
        arrangement.appendArtifactDraft(photoDraft)
        arrangement.appendArtifactDraft(videoDraft)
        arrangement.toggleStackWithPrevious(draftID: videoID)

        arrangement.removeArtifactDraft(photoID, artifactDrafts: [videoDraft])

        let node = arrangement.nodes.first
        XCTAssertEqual(arrangement.nodes.count, 1)
        XCTAssertEqual(node?.contentRef, .artifactDraft(videoID))
        XCTAssertEqual(node?.visualRecipe, .filmFrame)
        XCTAssertEqual(node?.layout.size, .hero)
    }

    func testSyncRestoresSingleRemainingGroupRecipeFromCurrentDrafts() {
        let musicID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let linkID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let linkDraft = CaptureArtifactDraft(
            draftID: linkID,
            origin: .manual,
            content: .link(LinkArtifactContent(title: "Link", url: "https://example.com"))
        )

        var arrangement = MemoryCardArrangementDraft(nodes: [
            MemoryCardDraftNode(
                contentRef: .artifactDraftGroup([musicID, linkID], kind: .mediaStack),
                visualRecipe: .bundlePacket,
                layout: MemoryCardLayoutToken(order: 0, size: .stack)
            )
        ])

        arrangement.sync(recordBodyIsPresent: false, artifactDrafts: [linkDraft])

        let node = arrangement.nodes.first
        XCTAssertEqual(arrangement.nodes.count, 1)
        XCTAssertEqual(node?.contentRef, .artifactDraft(linkID))
        XCTAssertEqual(node?.visualRecipe, .linkNote)
        XCTAssertEqual(node?.layout.size, .medium)
    }

    func testPersistedArrangementSyncRestoresRemainingGroupArtifactRecipe() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recordID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        let photoID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        let videoID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let record = RecordShell(
            id: recordID,
            createdAt: now,
            updatedAt: now,
            captureSource: .composer,
            rawText: "Keep the remaining card identity.",
            artifactIDs: [videoID]
        )
        let video = Artifact(
            id: videoID,
            recordID: recordID,
            kind: .video,
            title: "Clip",
            summary: "Video summary",
            textContent: "Video summary",
            createdAt: now,
            updatedAt: now
        )
        let arrangement = MemoryCardArrangement(
            recordID: recordID,
            nodes: [
                MemoryCardNode(
                    contentRef: .artifactGroup([photoID, videoID], kind: .mediaStack),
                    visualRecipe: .bundlePacket,
                    layout: MemoryCardLayoutToken(order: 0, size: .stack)
                )
            ],
            createdAt: now,
            updatedAt: now
        )

        let synchronized = arrangement.synchronized(
            record: record,
            artifacts: [video],
            artifactOrder: [videoID],
            updatedAt: now
        )

        let node = synchronized.nodes.first
        XCTAssertEqual(synchronized.nodes.count, 2)
        XCTAssertTrue(synchronized.nodes.contains { $0.contentRef == .recordBody })
        XCTAssertEqual(node?.contentRef, .recordBody)
        let videoNode = synchronized.nodes.first { node in
            if case let .artifact(id) = node.contentRef {
                return id == videoID
            }
            return false
        }
        XCTAssertEqual(videoNode?.visualRecipe, .filmFrame)
        XCTAssertEqual(videoNode?.layout.size, .hero)
    }
}
