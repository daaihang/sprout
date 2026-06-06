import XCTest
@testable import mory

final class MemoryCardArrangementEditingTests: XCTestCase {
    func testAutoArrangeNormalizesOrderAndPreservesVisualMetadata() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recordID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let photoID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let audioID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let todoID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let arrangement = MemoryCardArrangement(
            recordID: recordID,
            nodes: [
                MemoryCardNode(
                    contentRef: .artifact(photoID),
                    visualRecipe: .polaroid,
                    layout: MemoryCardLayoutToken(order: 2, rotationDegrees: -2, xNudge: 3, zIndex: 8)
                ),
                MemoryCardNode(
                    contentRef: .artifactGroup([audioID, todoID], kind: .mediaStack),
                    visualRecipe: .bundlePacket,
                    layout: MemoryCardLayoutToken(order: 1, rotationDegrees: 1, yNudge: -4, zIndex: 4)
                )
            ],
            createdAt: now,
            updatedAt: now
        )

        let arranged = arrangement.autoArranged(updatedAt: now)

        XCTAssertEqual(arranged.nodes.map(\.layout.order), [0, 1])
        XCTAssertEqual(arranged.nodes.map(\.layout.zIndex), [0, 1])
        XCTAssertEqual(arranged.nodes.map(\.visualRecipe), [.bundlePacket, .polaroid])
        XCTAssertEqual(arranged.nodes[0].layout.rotationDegrees, 1)
        XCTAssertEqual(arranged.nodes[0].layout.yNudge, -4)
        XCTAssertEqual(arranged.nodes[1].layout.rotationDegrees, -2)
        XCTAssertEqual(arranged.nodes[1].layout.xNudge, 3)
    }

    func testMoveEarlierLaterUsesExistingNodesInsteadOfDefaultArrangement() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recordID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let photoID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let audioID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        let arrangement = MemoryCardArrangement(
            recordID: recordID,
            nodes: [
                MemoryCardNode(
                    contentRef: .artifact(photoID),
                    visualRecipe: .polaroid,
                    layout: MemoryCardLayoutToken(order: 0)
                ),
                MemoryCardNode(
                    contentRef: .artifact(audioID),
                    visualRecipe: .cassette,
                    layout: MemoryCardLayoutToken(order: 1)
                )
            ],
            createdAt: now,
            updatedAt: now
        )

        let moved = arrangement.movingArtifact(artifactID: audioID, by: -1, updatedAt: now)

        XCTAssertEqual(moved.nodes.first?.contentRef, .artifact(audioID))
        XCTAssertEqual(moved.nodes.first?.visualRecipe, .cassette)
        XCTAssertEqual(moved.nodes.first?.layout.order, 0)
        XCTAssertEqual(moved.nodes.last?.visualRecipe, .polaroid)
        XCTAssertEqual(moved.nodes.last?.layout.order, 1)
    }

    func testStickersArePreservedThroughNormalization() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recordID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let artifactID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let sticker = MemoryCardStickerAttachment(
            corner: .topTrailing,
            kind: .sparkle,
            xOffset: 4,
            yOffset: -3,
            rotationDegrees: 12,
            zIndex: 2
        )
        let arrangement = MemoryCardArrangement(
            recordID: recordID,
            nodes: [
                MemoryCardNode(
                    contentRef: .artifact(artifactID),
                    visualRecipe: .linkNote,
                    layout: MemoryCardLayoutToken(order: 0, stickers: [sticker])
                )
            ],
            createdAt: now,
            updatedAt: now
        )

        let arranged = arrangement.autoArranged(updatedAt: now)

        XCTAssertEqual(arranged.nodes.first?.layout.stickers, [sticker])
    }
}
