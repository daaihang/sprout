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
        XCTAssertEqual(nodesByDraftID[photoID]?.layout.size, .card)
        XCTAssertEqual(nodesByDraftID[videoID]?.visualRecipe, .filmFrame)
        XCTAssertEqual(nodesByDraftID[videoID]?.layout.size, .card)
        XCTAssertEqual(nodesByDraftID[audioID]?.visualRecipe, .cassette)
        XCTAssertEqual(nodesByDraftID[audioID]?.layout.size, .strip)
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
        XCTAssertEqual(node?.layout.size, .card)
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
                layout: MemoryCardLayoutToken(order: 0, size: .card)
            )
        ])

        arrangement.sync(recordBodyIsPresent: false, artifactDrafts: [linkDraft])

        let node = arrangement.nodes.first
        XCTAssertEqual(arrangement.nodes.count, 1)
        XCTAssertEqual(node?.contentRef, .artifactDraft(linkID))
        XCTAssertEqual(node?.visualRecipe, .linkNote)
        XCTAssertEqual(node?.layout.size, .card)
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
                    layout: MemoryCardLayoutToken(order: 0, size: .card)
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
        XCTAssertEqual(videoNode?.layout.size, .card)
    }

    func testSizeChangeAndReorderRepackDraftGridPlacements() {
        let photoID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let audioID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let linkID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        let drafts = [
            CaptureArtifactDraft(
                draftID: photoID,
                origin: .manual,
                content: .photo(PhotoArtifactContent(title: "Photo", summary: "photo", filename: "photo.jpg"))
            ),
            CaptureArtifactDraft(
                draftID: audioID,
                origin: .manual,
                content: .audio(AudioArtifactContent(title: "Audio", summary: "audio", filename: "audio.caf"))
            ),
            CaptureArtifactDraft(
                draftID: linkID,
                origin: .manual,
                content: .link(LinkArtifactContent(title: "Link", url: "https://example.com"))
            )
        ]
        var arrangement = MemoryCardArrangementDraft()
        drafts.forEach { arrangement.appendArtifactDraft($0) }

        arrangement.setSize(.card, forDraftID: audioID)
        arrangement.reorderArtifactDraft(from: linkID, to: audioID)

        XCTAssertEqual(arrangement.nodes.map(\.layout.order), [0, 1, 2])
        XCTAssertTrue(arrangement.nodes.allSatisfy { $0.layout.gridPlacement != nil })
        let audioNode = arrangement.nodes.first { node in
            if case let .artifactDraft(id) = node.contentRef { return id == audioID }
            return false
        }
        XCTAssertEqual(audioNode?.layout.size, .card)
    }

    func testWeatherDraftDefaultsToStampVariant() {
        let weatherDraft = CaptureArtifactDraft.weather(
            condition: "Cloudy",
            temperatureCelsius: 22,
            humidity: 0.6,
            windSpeedKmh: 8,
            uvIndex: 3
        )
        var arrangement = MemoryCardArrangementDraft()
        arrangement.appendArtifactDraft(weatherDraft)

        let weatherNode = arrangement.nodes.first
        XCTAssertEqual(weatherNode?.visualRecipe, .weatherStamp)
        XCTAssertEqual(weatherNode?.layout.size, .stamp)
        XCTAssertEqual(weatherNode?.visualVariant, .weatherIcon)
    }

    func testWeatherVariantNormalizesWhenChangingSize() {
        let weatherDraft = CaptureArtifactDraft.weather(
            condition: "Rain",
            temperatureCelsius: 17,
            humidity: 0.78,
            windSpeedKmh: 19,
            uvIndex: 1
        )
        var arrangement = MemoryCardArrangementDraft()
        arrangement.appendArtifactDraft(weatherDraft)
        arrangement.setVisualVariant(.weatherWind, forDraftID: weatherDraft.draftID)

        arrangement.setSize(.strip, forDraftID: weatherDraft.draftID)
        let stripNode = arrangement.nodes.first
        XCTAssertEqual(stripNode?.layout.size, .strip)
        XCTAssertEqual(stripNode?.visualVariant, .weatherIconTemperature)

        arrangement.setSize(.card, forDraftID: weatherDraft.draftID)
        let cardNode = arrangement.nodes.first
        XCTAssertEqual(cardNode?.layout.size, .card)
        XCTAssertEqual(cardNode?.visualVariant, .weatherFullMetrics)
    }

    func testWeatherVariantSurvivesResolveToPersistedArrangement() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recordID = UUID(uuidString: "EFEFEFEF-EFEF-EFEF-EFEF-EFEFEFEFEFEF")!
        let weatherDraft = CaptureArtifactDraft.weather(
            condition: "Cloudy",
            temperatureCelsius: 22,
            humidity: 0.65,
            windSpeedKmh: 12,
            uvIndex: 2
        )
        var draftArrangement = MemoryCardArrangementDraft()
        draftArrangement.appendArtifactDraft(weatherDraft)
        draftArrangement.setVisualVariant(.weatherHumidity, forDraftID: weatherDraft.draftID)

        let weatherArtifact = Artifact(
            id: UUID(uuidString: "FAFAFAFA-FAFA-FAFA-FAFA-FAFAFAFAFAFA")!,
            recordID: recordID,
            kind: .weather,
            title: "22°C",
            summary: "Cloudy",
            metadata: [
                "condition": "Cloudy",
                "temperatureCelsius": "22",
                "humidity": "0.65",
                "windSpeedKmh": "12",
                "uvIndex": "2",
            ],
            createdAt: now,
            updatedAt: now
        )
        let record = RecordShell(
            id: recordID,
            createdAt: now,
            updatedAt: now,
            captureSource: .composer,
            rawText: "",
            artifactIDs: [weatherArtifact.id]
        )
        let mapping = [weatherDraft.draftID: weatherArtifact.id]

        let resolved = draftArrangement.resolve(
            record: record,
            artifacts: [weatherArtifact],
            artifactIDByDraftID: mapping,
            createdAt: now
        )

        let node = resolved.nodes.first
        XCTAssertEqual(node?.contentRef, .artifact(weatherArtifact.id))
        XCTAssertEqual(node?.layout.size, .stamp)
        XCTAssertEqual(node?.visualVariant, .weatherHumidity)
    }
}
