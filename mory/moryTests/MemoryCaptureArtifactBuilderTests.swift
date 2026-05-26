import XCTest
@testable import mory

final class MemoryCaptureArtifactBuilderTests: XCTestCase {
    func testCaptureArtifactDraftStoresOriginAndProvenanceOutsideContent() throws {
        let provenance = CaptureProvenance.manualCamera
        let draft = CaptureArtifactDraft.photo(
            title: "Whiteboard",
            summary: "Planning notes",
            filename: "whiteboard.jpg",
            origin: .manual
        )

        let updated = draft
            .withOrigin(.imported)
            .withProvenance(provenance)

        XCTAssertEqual(updated.origin, .imported)
        XCTAssertEqual(updated.provenance, provenance)
        guard case let .photo(content) = updated.content else {
            return XCTFail("Expected photo content")
        }
        XCTAssertEqual(content.filename, "whiteboard.jpg")
        XCTAssertEqual(content.summary, "Planning notes")
    }

    func testBuildArtifactsPersistsCaptureOriginMetadata() throws {
        let builder = MemoryCaptureArtifactBuilder()
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let recordID = UUID()

        let draft = MemoryCaptureDraft(
            title: nil,
            rawText: "Memory body",
            captureSource: .composer,
            artifacts: [
                .text(title: nil, body: "Memory body", origin: .manual),
                .location(
                    title: "Cafe",
                    summary: "Nanjing Road",
                    latitude: 31.231,
                    longitude: 121.473,
                    origin: .context
                ),
                .todo(title: "Follow up", note: "Send recap", origin: .imported)
            ]
        )

        let artifacts = builder.buildArtifacts(from: draft, recordID: recordID, createdAt: createdAt)

        let text = try XCTUnwrap(artifacts.first(where: { $0.kind == .text }))
        XCTAssertEqual(text.metadata["captureOrigin"], CaptureArtifactOrigin.manual.rawValue)

        let location = try XCTUnwrap(artifacts.first(where: { $0.kind == .location }))
        XCTAssertEqual(location.metadata["captureOrigin"], CaptureArtifactOrigin.context.rawValue)

        let todo = try XCTUnwrap(artifacts.first(where: { $0.kind == .todo }))
        XCTAssertEqual(todo.metadata["captureOrigin"], CaptureArtifactOrigin.imported.rawValue)
    }

    func testBuildArtifactsPersistsMusicArtworkPaletteMetadata() throws {
        let builder = MemoryCaptureArtifactBuilder()
        let artifacts = builder.buildArtifacts(
            from: MemoryCaptureDraft(
                rawText: "",
                artifacts: [
                    .music(
                        trackName: "Intro",
                        artistName: "The Band",
                        albumName: "Morning",
                        durationSeconds: 180,
                        artworkURL: "https://example.com/art.jpg",
                        artworkPalette: MusicArtworkPalette(
                            backgroundColorHex: "#123456",
                            primaryTextColorHex: "#FFFFFF",
                            secondaryTextColorHex: "#DDDDDD"
                        ),
                        origin: .manual
                    )
                ]
            ),
            recordID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let music = try XCTUnwrap(artifacts.first(where: { $0.kind == .music }))
        XCTAssertEqual(music.metadata["artworkURL"], "https://example.com/art.jpg")
        XCTAssertEqual(music.metadata["artworkBackgroundColor"], "#123456")
        XCTAssertEqual(music.metadata["artworkPrimaryTextColor"], "#FFFFFF")
        XCTAssertEqual(music.metadata["artworkSecondaryTextColor"], "#DDDDDD")
    }

    func testBuildArtifactsPersistsVideoPreviewAndMetadata() throws {
        let builder = MemoryCaptureArtifactBuilder()
        let videoData = Data([0, 1, 2, 3, 4, 5])
        let thumbnailData = Data([9, 8, 7])
        let artifacts = builder.buildArtifacts(
            from: MemoryCaptureDraft(
                rawText: "",
                artifacts: [
                    .video(
                        title: "Clip",
                        summary: "Short clip",
                        filename: "clip.mov",
                        videoData: videoData,
                        thumbnailData: thumbnailData,
                        videoMetadata: ["durationSeconds": "12"],
                        origin: .manual,
                        provenance: .manualCamera
                    )
                ]
            ),
            recordID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let video = try XCTUnwrap(artifacts.first(where: { $0.kind == .video }))
        XCTAssertEqual(video.binaryPayload, videoData)
        XCTAssertEqual(video.previewPayload, thumbnailData)
        XCTAssertEqual(video.mediaRef?.mimeType, "video/quicktime")
        XCTAssertEqual(video.metadata["durationSeconds"], "12")
        XCTAssertEqual(video.metadata["byteCount"], "\(videoData.count)")
        XCTAssertEqual(video.captureProvenance?.sourceKind, .camera)
    }

    func testBuildArtifactsPersistsLivePhotoAsSingleArtifact() throws {
        let builder = MemoryCaptureArtifactBuilder()
        let stillData = Data([1, 2, 3])
        let pairedVideoData = Data([4, 5, 6, 7])
        let provenance = CaptureProvenance.external(sourceKind: .journalingSuggestion)
        let artifacts = builder.buildArtifacts(
            from: MemoryCaptureDraft(
                rawText: "",
                provenance: provenance,
                artifacts: [
                    .livePhoto(
                        title: "Live",
                        summary: "Motion still",
                        stillFilename: "live.heic",
                        videoFilename: "live.mov",
                        stillImageData: stillData,
                        pairedVideoData: pairedVideoData,
                        thumbnailData: stillData,
                        metadata: ["localIdentifier": "asset-id"],
                        origin: .imported,
                        provenance: provenance
                    )
                ]
            ),
            recordID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let livePhoto = try XCTUnwrap(artifacts.first(where: { $0.kind == .livePhoto }))
        XCTAssertEqual(artifacts.filter { $0.kind == .livePhoto }.count, 1)
        XCTAssertEqual(livePhoto.binaryPayload, pairedVideoData)
        XCTAssertEqual(livePhoto.previewPayload, stillData)
        XCTAssertEqual(livePhoto.mediaRef?.filename, "live.heic")
        XCTAssertEqual(livePhoto.metadata["stillFilename"], "live.heic")
        XCTAssertEqual(livePhoto.metadata["videoFilename"], "live.mov")
        XCTAssertEqual(livePhoto.metadata["pairedVideoByteCount"], "\(pairedVideoData.count)")
        XCTAssertEqual(livePhoto.captureProvenance, provenance)
    }

    func testBuildArtifactsPersistsWeatherConditionMetadata() throws {
        let builder = MemoryCaptureArtifactBuilder()
        let artifacts = builder.buildArtifacts(
            from: MemoryCaptureDraft(
                rawText: "",
                artifacts: [
                    .weather(
                        condition: "大部晴朗无云",
                        temperatureCelsius: 21,
                        humidity: 0.48,
                        windSpeedKmh: 9,
                        uvIndex: 4,
                        latitude: 31.23,
                        longitude: 121.47,
                        conditionCode: "mostlyClear",
                        symbolName: "sun.max.fill",
                        isDaylight: true,
                        origin: .context
                    )
                ]
            ),
            recordID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let weather = try XCTUnwrap(artifacts.first(where: { $0.kind == .weather }))
        XCTAssertEqual(weather.metadata["condition"], "大部晴朗无云")
        XCTAssertEqual(weather.metadata["conditionCode"], "mostlyClear")
        XCTAssertEqual(weather.metadata["symbolName"], "sun.max.fill")
        XCTAssertEqual(weather.metadata["isDaylight"], "true")
        XCTAssertEqual(weather.metadata["captureOrigin"], CaptureArtifactOrigin.context.rawValue)
    }

    func testBuildArtifactsPersistsCaptureProvenanceMetadataAndModel() throws {
        let builder = MemoryCaptureArtifactBuilder()
        let recordID = UUID()
        let sessionID = UUID()
        let inboxItemID = UUID()
        let provenance = CaptureProvenance.external(
            sourceKind: .shareSheet,
            importSessionID: sessionID,
            externalInboxItemID: inboxItemID,
            sourceDisplayName: "Share Sheet",
            createdAt: Date(timeIntervalSince1970: 1_800_000_010)
        )
        let draft = MemoryCaptureDraft(
            rawText: "Shared page",
            captureSource: .importFile,
            provenance: provenance,
            artifacts: [
                .link(
                    title: "Shared page",
                    url: "https://example.com",
                    note: "Worth saving",
                    origin: .imported,
                    provenance: provenance
                )
            ]
        )

        let artifacts = builder.buildArtifacts(
            from: draft,
            recordID: recordID,
            createdAt: Date(timeIntervalSince1970: 1_800_000_020)
        )

        let link = try XCTUnwrap(artifacts.first(where: { $0.kind == .link }))
        XCTAssertEqual(link.captureProvenance?.sourceKind, .shareSheet)
        XCTAssertEqual(link.captureProvenance?.importSessionID, sessionID)
        XCTAssertEqual(link.captureProvenance?.externalInboxItemID, inboxItemID)
        XCTAssertEqual(link.metadata["captureOrigin"], CaptureArtifactOrigin.imported.rawValue)
        XCTAssertEqual(link.metadata["captureOriginCategory"], CaptureOriginCategory.externalImport.rawValue)
        XCTAssertEqual(link.metadata["captureSourceKind"], CaptureProvenanceSourceKind.shareSheet.rawValue)
        XCTAssertEqual(link.metadata["captureImportSessionID"], sessionID.uuidString)
        XCTAssertEqual(link.metadata["externalInboxItemID"], inboxItemID.uuidString)
    }
}
