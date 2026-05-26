import SwiftData
import XCTest
@testable import mory

final class AppRuntimeEnvironmentTests: XCTestCase {
    func testBuildChannelParsesInternalPublicAndProductionValues() {
        XCTAssertEqual(AppRuntimeEnvironment.BuildChannel(rawBundleValue: "InternalBeta"), .internalBeta)
        XCTAssertEqual(AppRuntimeEnvironment.BuildChannel(rawBundleValue: "internal_beta"), .internalBeta)
        XCTAssertEqual(AppRuntimeEnvironment.BuildChannel(rawBundleValue: "PublicBeta"), .publicBeta)
        XCTAssertEqual(AppRuntimeEnvironment.BuildChannel(rawBundleValue: "production"), .production)
        XCTAssertEqual(AppRuntimeEnvironment.BuildChannel(rawBundleValue: nil), .unknown)
    }

    func testDebugToolsAreAllowedOnlyForDevelopmentOrInternalBetaTestFlight() {
        let debug = AppRuntimeEnvironment(
            buildChannel: .production,
            distribution: .debug,
            bundleIdentifier: "com.speculolabs.mory",
            version: "0.0.1",
            buildNumber: "1"
        )
        let internalTestFlight = AppRuntimeEnvironment(
            buildChannel: .internalBeta,
            distribution: .testFlight,
            bundleIdentifier: "com.speculolabs.mory",
            version: "0.0.1",
            buildNumber: "1"
        )
        let publicTestFlight = AppRuntimeEnvironment(
            buildChannel: .publicBeta,
            distribution: .testFlight,
            bundleIdentifier: "com.speculolabs.mory",
            version: "0.0.1",
            buildNumber: "1"
        )
        let appStore = AppRuntimeEnvironment(
            buildChannel: .internalBeta,
            distribution: .appStore,
            bundleIdentifier: "com.speculolabs.mory",
            version: "0.0.1",
            buildNumber: "1"
        )

        XCTAssertTrue(debug.allowsDebugTools)
        XCTAssertTrue(internalTestFlight.allowsDebugTools)
        XCTAssertFalse(publicTestFlight.allowsDebugTools)
        XCTAssertFalse(appStore.allowsDebugTools)
    }

    func testDefaultAPIBaseURLMatchesRuntimeTarget() {
        #if targetEnvironment(simulator)
        XCTAssertEqual(MoryAPIConfiguration.defaultBaseURL.absoluteString, "http://127.0.0.1:8080")
        #else
        XCTAssertEqual(MoryAPIConfiguration.defaultBaseURL.absoluteString, "https://sprout-god7g.fly.dev")
        #endif
    }
}

@MainActor
final class MoryMemoryRepositoryCompositionTests: XCTestCase {
    func testCreateMemoryDerivesCaptureSourceFromProvenance() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let importSessionID = UUID()
        let provenance = CaptureProvenance.external(
            sourceKind: .shareSheet,
            importSessionID: importSessionID,
            sourceDisplayName: "Share Sheet",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Shared article",
                rawText: "Shared from Safari",
                provenance: provenance,
                artifacts: [.link(title: "Shared article", url: "https://example.com", origin: .imported, provenance: provenance)]
            )
        )

        XCTAssertEqual(memory.record.captureSource, .importFile)
        XCTAssertEqual(memory.record.captureProvenance, provenance)
    }

    func testCreateMemoryPersistsSemanticDigestsAndDefaultCardArrangement() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Media walk",
                rawText: "I walked through the old lane and kept a few traces.",
                mood: "calm",
                inputContext: "typed in composer",
                artifacts: [
                    .text(title: "Media walk", body: "I walked through the old lane and kept a few traces."),
                    .photo(
                        title: "Window",
                        summary: "window, flowers | Text: afternoon market",
                        filename: "window.jpg",
                        photoMetadata: [
                            "width": "1200",
                            "height": "900",
                            "localIdentifier": "photo-1"
                        ]
                    ),
                    .video(
                        title: "Street clip",
                        summary: "Short clip",
                        filename: "street.mov",
                        videoData: Data([1, 2, 3, 4]),
                        thumbnailData: Data([9]),
                        videoMetadata: ["durationSeconds": "4.5"]
                    ),
                    .livePhoto(
                        title: "Doorway",
                        summary: "doorway | Text: quiet",
                        stillFilename: "doorway.heic",
                        videoFilename: "doorway.mov",
                        stillImageData: Data([5, 6]),
                        pairedVideoData: Data([7, 8, 9]),
                        thumbnailData: Data([5]),
                        metadata: ["localIdentifier": "live-1"]
                    )
                ]
            )
        )

        let detail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        let digests = detail.artifactSemanticDigests
        XCTAssertEqual(digests.count, 3)

        let photoDigest = try XCTUnwrap(digests.first(where: { $0.artifactKind == .photo }))
        XCTAssertEqual(photoDigest.ocrText, "afternoon market")
        XCTAssertEqual(photoDigest.visualLabels, ["window", "flowers"])
        XCTAssertEqual(photoDigest.dimensions?.width, 1200)
        XCTAssertEqual(photoDigest.localIdentifier, "photo-1")

        let videoDigest = try XCTUnwrap(digests.first(where: { $0.artifactKind == .video }))
        XCTAssertEqual(videoDigest.durationSeconds, 4.5)
        XCTAssertTrue(videoDigest.technicalNotes.contains("filename=street.mov"))

        let livePhotoDigest = try XCTUnwrap(digests.first(where: { $0.artifactKind == .livePhoto }))
        XCTAssertEqual(livePhotoDigest.localIdentifier, "live-1")
        XCTAssertTrue(livePhotoDigest.technicalNotes.contains("videoFilename=doorway.mov"))

        let arrangement = try XCTUnwrap(detail.cardArrangement)
        XCTAssertEqual(arrangement.recordID, memory.record.id)
        XCTAssertEqual(arrangement.nodes.count, 4)
        XCTAssertTrue(arrangement.nodes.contains { $0.contentRef == .recordBody && $0.visualRecipe == .notebook })

        let nodesByArtifactID = Dictionary(uniqueKeysWithValues: arrangement.nodes.compactMap { node -> (UUID, MemoryCardNode)? in
            guard case let .artifact(artifactID) = node.contentRef else { return nil }
            return (artifactID, node)
        })
        let photoID = try XCTUnwrap(detail.artifacts.first(where: { $0.kind == .photo })?.id)
        let videoID = try XCTUnwrap(detail.artifacts.first(where: { $0.kind == .video })?.id)
        let livePhotoID = try XCTUnwrap(detail.artifacts.first(where: { $0.kind == .livePhoto })?.id)
        XCTAssertEqual(nodesByArtifactID[photoID]?.visualRecipe, .polaroid)
        XCTAssertEqual(nodesByArtifactID[videoID]?.visualRecipe, .filmFrame)
        XCTAssertEqual(nodesByArtifactID[livePhotoID]?.visualRecipe, .livePhotoPrint)
    }

    func testCreateMemoryRemapsArrangementDraftIDsToPersistedArtifactIDs() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )
        let photoDraftID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let audioDraftID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let photoDraft = CaptureArtifactDraft(
            draftID: photoDraftID,
            origin: .manual,
            content: .photo(PhotoArtifactContent(title: "Draft photo", summary: "window", filename: "draft.jpg"))
        )
        let audioDraft = CaptureArtifactDraft(
            draftID: audioDraftID,
            origin: .manual,
            content: .audio(AudioArtifactContent(title: "Draft audio", summary: "voice", filename: "draft.caf", transcriptionText: "voice"))
        )
        let arrangementDraft = MemoryCardArrangementDraft(nodes: [
            MemoryCardDraftNode(
                contentRef: .recordBody,
                visualRecipe: .notebook,
                layout: MemoryCardLayoutToken(order: 0, size: .wide)
            ),
            MemoryCardDraftNode(
                contentRef: .artifactDraftGroup([photoDraftID, audioDraftID], kind: .mediaStack),
                visualRecipe: .bundlePacket,
                layout: MemoryCardLayoutToken(order: 1, size: .stack, rotationDegrees: -2)
            )
        ])

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                rawText: "A stacked draft",
                artifacts: [photoDraft, audioDraft],
                cardArrangement: arrangementDraft
            )
        )

        let detail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        let photoID = try XCTUnwrap(detail.artifacts.first(where: { $0.kind == .photo })?.id)
        let audioID = try XCTUnwrap(detail.artifacts.first(where: { $0.kind == .audio })?.id)
        let arrangement = try XCTUnwrap(detail.cardArrangement)
        let group = try XCTUnwrap(arrangement.nodes.first { node in
            if case .artifactGroup = node.contentRef { return true }
            return false
        })

        if case let .artifactGroup(ids, kind) = group.contentRef {
            XCTAssertEqual(kind, .mediaStack)
            XCTAssertEqual(ids, [photoID, audioID])
            XCTAssertFalse(ids.contains(photoDraftID))
            XCTAssertFalse(ids.contains(audioDraftID))
        } else {
            XCTFail("Expected remapped artifact group")
        }
    }

    func testMemoryMutationKeepsSemanticDigestsAndCardArrangementInSync() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                rawText: "A mutable memory",
                artifacts: [
                    .text(title: nil, body: "A mutable memory"),
                    .photo(
                        title: "First photo",
                        summary: "photo | Text: first",
                        filename: "first.jpg"
                    ),
                    .video(
                        title: "Clip",
                        summary: "clip",
                        filename: "clip.mov",
                        videoData: Data([1, 2, 3]),
                        thumbnailData: Data([9]),
                        videoMetadata: ["durationSeconds": "7"]
                    )
                ]
            )
        )
        let initialDetail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        let photoID = try XCTUnwrap(initialDetail.artifacts.first(where: { $0.kind == .photo })?.id)
        let videoID = try XCTUnwrap(initialDetail.artifacts.first(where: { $0.kind == .video })?.id)

        let result = try await repository.applyMemoryMutation(
            recordID: memory.record.id,
            mutation: MemoryMutationDraft(
                deletedArtifactIDs: [videoID],
                artifactOrder: [photoID]
            ),
            refreshPolicy: .saveOnly
        )

        let detail = try XCTUnwrap(result.detail)
        XCTAssertNil(detail.artifacts.first(where: { $0.id == videoID }))
        XCTAssertNil(detail.artifactSemanticDigests.first(where: { $0.artifactID == videoID }))
        XCTAssertNotNil(detail.artifactSemanticDigests.first(where: { $0.artifactID == photoID }))

        let arrangement = try XCTUnwrap(detail.cardArrangement)
        XCTAssertFalse(arrangement.nodes.contains { node in
            if case let .artifact(id) = node.contentRef {
                return id == videoID
            }
            return false
        })
        XCTAssertTrue(arrangement.nodes.contains { node in
            if case let .artifact(id) = node.contentRef {
                return id == photoID
            }
            return false
        })
    }

    func testUserSettingsPreferenceDefaultsPersistAndSurviveLocalDataClear() throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let defaults = try repository.fetchUserSettingsPreference()
        XCTAssertEqual(defaults.syncKey, UserSettingsPreference.defaultSyncKey)
        XCTAssertEqual(defaults.schemaVersion, UserSettingsPreference.schemaVersion)
        XCTAssertTrue(defaults.linkAutoDetectEnabled)

        var edited = defaults
        edited.appearanceMode = .dark
        edited.voiceLanguageIdentifier = "en-US"
        edited.linkAutoDetectEnabled = false
        edited.defaultContextSelection = .manual
        edited.insightFrequency = .high
        edited.promptTone = .reflective
        edited.updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        try repository.saveUserSettingsPreference(edited)

        var stored = try repository.fetchUserSettingsPreference()
        XCTAssertEqual(stored.syncKey, edited.syncKey)
        XCTAssertEqual(stored.schemaVersion, edited.schemaVersion)
        XCTAssertEqual(stored.appearanceMode, .dark)
        XCTAssertEqual(stored.voiceLanguageIdentifier, "en-US")
        XCTAssertFalse(stored.linkAutoDetectEnabled)
        XCTAssertEqual(stored.defaultContextSelection, .manual)
        XCTAssertEqual(stored.insightFrequency, .high)
        XCTAssertEqual(stored.promptTone, .reflective)

        try repository.clearAllLocalData()

        stored = try repository.fetchUserSettingsPreference()
        XCTAssertEqual(stored.appearanceMode, .dark)
        XCTAssertEqual(stored.voiceLanguageIdentifier, "en-US")
        XCTAssertFalse(stored.linkAutoDetectEnabled)
    }

    func testSettingsLocalDataExportIncludesMemoriesInsightsAndSettings() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        var preference = try repository.fetchUserSettingsPreference()
        preference.appearanceMode = .dark
        try repository.saveUserSettingsPreference(preference)

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Export sample",
                rawText: "Met Linh to discuss the public beta launch scope.",
                mood: "focused",
                inputContext: "settings export test",
                captureSource: .composer,
                artifacts: [.text(title: "Export sample", body: "Met Linh to discuss the public beta launch scope.")]
            )
        )

        let snapshot = try SettingsLocalDataExportSnapshot.make(
            repository: repository,
            exportedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let encoded = try snapshot.encodedData()

        XCTAssertEqual(snapshot.settings.appearanceMode, .dark)
        XCTAssertEqual(snapshot.memories.count, 1)
        XCTAssertEqual(snapshot.memories.first?.title, "Export sample")
        XCTAssertEqual(snapshot.memories.first?.artifacts.first?.kind, ArtifactKind.text.rawValue)
        XCTAssertFalse(encoded.isEmpty)
    }

    func testFetchHomeBoardReturnsCompositionDrivenMemoryRenderValues() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Train insight",
                rawText: "Walked in the rain and the quarter plan clicked.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Train insight", body: "Walked in the rain and the quarter plan clicked.")]
            )
        )

        let board = try repository.fetchHomeBoard(for: Date(), limit: 8)

        XCTAssertFalse(board.items.isEmpty)
        XCTAssertTrue(board.items.contains {
            if case .memory = $0.renderValue { return true }
            return false
        })
    }

    func testFetchHomeBoardDebugSnapshotExposesInputsPreferencesAndReasons() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Observable board",
                rawText: "Observable board memory with Linh and planning.",
                mood: "focused",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [
                    .text(title: "Observable board", body: "Observable board memory with Linh and planning."),
                    .music(trackName: "Dreams", artistName: "Fleetwood Mac", albumName: "Rumours", durationSeconds: 257, artworkURL: nil)
                ]
            )
        )

        var debug = try repository.fetchHomeBoardDebugSnapshot(for: Date(), limit: 8)
        XCTAssertEqual(debug.input.memoryCount, 1)
        XCTAssertEqual(debug.input.contextMemoryCount, 1)
        XCTAssertFalse(debug.board.items.isEmpty)
        XCTAssertTrue(debug.board.items.allSatisfy { !$0.reason.isEmpty })

        let item = try XCTUnwrap(debug.board.items.first { $0.cardKind == .memory })
        try repository.updateHomeBoardItemPreference(item, action: .pin(true))

        debug = try repository.fetchHomeBoardDebugSnapshot(for: Date(), limit: 8)
        XCTAssertEqual(debug.preferences.totalCount, 1)
        XCTAssertEqual(debug.preferences.pinnedCount, 1)
        XCTAssertTrue(debug.board.items.contains { $0.compositionItem.itemKey == item.compositionItem.itemKey && $0.isPinned })
    }

    func testFetchHomeBoardRanksTodayMemoriesBeforeOlderMemories() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        for index in 1...4 {
            _ = try await repository.createMemory(
                from: MemoryCaptureDraft(
                    title: "Memory \(index)",
                    rawText: "Memory \(index) with Linh and planning.",
                    mood: "focused",
                    inputContext: "typed in debug",
                    captureSource: .composer,
                    artifacts: [.text(title: "Memory \(index)", body: "Memory \(index) with Linh and planning.")]
                )
            )
        }
        if let oldRecord = try container.mainContext.fetch(
            FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.rawText == "Memory 1 with Linh and planning." })
        ).first {
            oldRecord.updatedAt = Date().addingTimeInterval(-72 * 60 * 60)
        }
        try container.mainContext.save()

        let board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        let memoryItems = board.items.compactMap { item -> MemorySummary? in
            if case let .memory(memory) = item.renderValue { return memory }
            return nil
        }

        XCTAssertFalse(memoryItems.isEmpty)
        XCTAssertNotEqual(memoryItems.first?.title, "Memory 1")
        XCTAssertTrue(board.items.allSatisfy { !$0.reason.isEmpty })
    }

    func testFetchHomeBoardCarriesContextArtifactsOnMemoryCards() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Context walk",
                rawText: "Walked home with context attached.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [
                    .text(title: "Context walk", body: "Walked home with context attached."),
                    .location(title: "Cafe", summary: "Cafe on Nanjing Road", latitude: 31.2, longitude: 121.4),
                    .weather(condition: "Cloudy", temperatureCelsius: 22, humidity: 0.6, windSpeedKmh: 8, uvIndex: 2),
                    .music(trackName: "Dreams", artistName: "Fleetwood Mac", albumName: "Rumours", durationSeconds: 257, artworkURL: nil)
                ]
            )
        )

        let board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        let memory = try XCTUnwrap(board.items.compactMap { item -> MemorySummary? in
            if case let .memory(memory) = item.renderValue { return memory }
            return nil
        }.first)

        XCTAssertEqual(Set(memory.contextArtifacts.map(\.kind)), Set([.location, .weather, .music]))
        XCTAssertTrue(memory.contextArtifacts.contains { $0.summary.contains("Cafe on Nanjing Road") })
        XCTAssertTrue(memory.contextArtifacts.contains { $0.summary.contains("Cloudy") })
        XCTAssertTrue(memory.contextArtifacts.contains { $0.summary.contains("Dreams") })
    }

    func testLocationArtifactsResolveIntoPersistentPlaceProfiles() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let firstMemory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Morning cafe",
                rawText: "Worked from the cafe before standup.",
                captureSource: .composer,
                artifacts: [
                    .text(title: "Morning cafe", body: "Worked from the cafe before standup."),
                    .location(title: "Blue Bottle", summary: "Blue Bottle Coffee Shanghai", latitude: 31.2000, longitude: 121.4000)
                ]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: firstMemory.record.id)

        let secondMemory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Cafe follow-up",
                rawText: "Returned to the same cafe entrance after lunch.",
                captureSource: .composer,
                artifacts: [
                    .text(title: "Cafe follow-up", body: "Returned to the same cafe entrance after lunch."),
                    .location(title: "Blue Bottle Coffee entrance", summary: "Blue Bottle by the station", latitude: 31.2004, longitude: 121.4003)
                ]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: secondMemory.record.id)

        var profiles = try repository.fetchPlaceProfiles(limit: nil)
        let mergedProfile = try XCTUnwrap(profiles.first { $0.sourceRecordIDs.contains(firstMemory.record.id) })
        XCTAssertEqual(mergedProfile.mentionCount, 2)
        XCTAssertEqual(Set(mergedProfile.sourceRecordIDs), Set([firstMemory.record.id, secondMemory.record.id]))
        XCTAssertEqual(mergedProfile.sourceArtifactIDs.count, 2)
        XCTAssertTrue(mergedProfile.aliases.contains { $0.contains("Blue Bottle") })

        let detail = try XCTUnwrap(repository.fetchEntityDetail(entityID: mergedProfile.entityID))
        XCTAssertEqual(detail.entity.kind, .place)
        XCTAssertGreaterThanOrEqual(detail.artifactCount, 2)

        let farMemory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Different city cafe",
                rawText: "Same cafe brand, different part of the city.",
                captureSource: .composer,
                artifacts: [
                    .text(title: "Different city cafe", body: "Same cafe brand, different part of the city."),
                    .location(title: "Blue Bottle", summary: "Blue Bottle Coffee Shanghai", latitude: 31.3000, longitude: 121.5000)
                ]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: farMemory.record.id)

        profiles = try repository.fetchPlaceProfiles(limit: nil)
        XCTAssertEqual(profiles.count, 2)
        XCTAssertTrue(profiles.contains { $0.sourceRecordIDs == [farMemory.record.id] })
    }

    func testPlaceProfileManualRenameMergeSplitAndDeletion() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let firstMemory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Cafe one",
                rawText: "Worked from the cafe.",
                captureSource: .composer,
                artifacts: [
                    .text(title: "Cafe one", body: "Worked from the cafe."),
                    .location(title: "Blue Bottle", summary: "Blue Bottle Coffee", latitude: 31.2000, longitude: 121.4000)
                ]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: firstMemory.record.id)

        let secondMemory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Cafe two",
                rawText: "Returned to the cafe entrance.",
                captureSource: .composer,
                artifacts: [
                    .text(title: "Cafe two", body: "Returned to the cafe entrance."),
                    .location(title: "Blue Bottle entrance", summary: "Blue Bottle Coffee", latitude: 31.2004, longitude: 121.4003)
                ]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: secondMemory.record.id)

        let farMemory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Far cafe",
                rawText: "Same brand, different district.",
                captureSource: .composer,
                artifacts: [
                    .text(title: "Far cafe", body: "Same brand, different district."),
                    .location(title: "Blue Bottle", summary: "Blue Bottle Coffee", latitude: 31.3000, longitude: 121.5000)
                ]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: farMemory.record.id)

        var profiles = try repository.fetchPlaceProfiles(limit: nil)
        XCTAssertEqual(profiles.count, 2)
        let primary = try XCTUnwrap(profiles.first { $0.sourceRecordIDs.contains(firstMemory.record.id) })
        let secondary = try XCTUnwrap(profiles.first { $0.sourceRecordIDs == [farMemory.record.id] })

        let renamed = try repository.renamePlaceProfile(
            id: primary.id,
            displayName: "Work Cafe",
            aliases: ["Morning cafe"]
        )
        XCTAssertEqual(renamed.displayName, "Work Cafe")
        XCTAssertEqual(renamed.confirmationState, .userConfirmed)
        XCTAssertTrue(renamed.aliases.contains("Morning cafe"))
        XCTAssertEqual(try repository.fetchEntityDetail(entityID: renamed.entityID)?.entity.displayName, "Work Cafe")

        let merged = try repository.mergePlaceProfiles(
            primaryID: renamed.id,
            mergingIDs: [secondary.id],
            displayName: "Work Cafe"
        )
        XCTAssertEqual(merged.confirmationState, .userConfirmed)
        XCTAssertEqual(Set(merged.sourceRecordIDs), Set([firstMemory.record.id, secondMemory.record.id, farMemory.record.id]))
        XCTAssertNil(try repository.fetchPlaceProfile(id: secondary.id))
        XCTAssertEqual(try repository.fetchPlaceProfiles(limit: nil).count, 1)

        let mergedArtifacts = try repository.fetchPlaceProfileArtifacts(id: merged.id)
        let movingArtifact = try XCTUnwrap(mergedArtifacts.first { $0.recordID == farMemory.record.id })
        let split = try repository.splitPlaceProfile(
            id: merged.id,
            movingArtifactIDs: [movingArtifact.id],
            displayName: "Other District Cafe"
        )
        XCTAssertEqual(split.displayName, "Other District Cafe")
        XCTAssertEqual(split.sourceArtifactIDs, [movingArtifact.id])
        XCTAssertEqual(split.sourceRecordIDs, [farMemory.record.id])
        XCTAssertEqual(try repository.fetchEntityDetail(entityID: split.entityID)?.artifactCount, 1)

        profiles = try repository.fetchPlaceProfiles(limit: nil)
        XCTAssertEqual(profiles.count, 2)
        let remainingPrimary = try XCTUnwrap(try repository.fetchPlaceProfile(id: merged.id))
        XCTAssertEqual(Set(remainingPrimary.sourceRecordIDs), Set([firstMemory.record.id, secondMemory.record.id]))

        XCTAssertThrowsError(try repository.splitPlaceProfile(
            id: split.id,
            movingArtifactIDs: split.sourceArtifactIDs,
            displayName: "Invalid split"
        ))

        try repository.deleteMemory(recordID: split.sourceRecordIDs[0])
        XCTAssertNil(try repository.fetchPlaceProfile(id: split.id))
    }

    func testHomeBoardCardMetadataReflectsTypedMemoryCard() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Metadata memory",
                rawText: "Metadata memory with a useful detail.",
                mood: "focused",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Metadata memory", body: "Metadata memory with a useful detail.")]
            )
        )

        let board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        let item = try XCTUnwrap(board.items.first { $0.cardKind == .memory })
        let metadata = HomeBoardCardMetadata(item: item)

        XCTAssertEqual(metadata.iconName, "doc.text")
        XCTAssertEqual(metadata.title, "Metadata memory")
        XCTAssertEqual(metadata.summary, "Metadata memory with a useful detail.")
        XCTAssertEqual(metadata.sourceCount, 1)
        XCTAssertTrue(metadata.accessibilityLabel.contains("Metadata memory"))
        XCTAssertTrue(metadata.accessibilityHint.contains(metadata.reason))
    }

    func testFetchHomeBoardAddsGuidanceWhenFewerThanThreeMemories() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "First memory",
                rawText: "First memory with Linh.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "First memory", body: "First memory with Linh.")]
            )
        )

        let board = try repository.fetchHomeBoard(for: Date(), limit: 8)

        XCTAssertTrue(board.items.contains {
            if case .systemPrompt = $0.renderValue { return true }
            return false
        })
    }

    func testHomeBoardPreferenceCanPinAndHideCards() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        for index in 1...3 {
            _ = try await repository.createMemory(
                from: MemoryCaptureDraft(
                    title: "Preference memory \(index)",
                    rawText: "Preference memory \(index) with Linh and planning.",
                    mood: "focused",
                    inputContext: "typed in debug",
                    captureSource: .composer,
                    artifacts: [.text(title: "Preference memory \(index)", body: "Preference memory \(index) with Linh and planning.")]
                )
            )
        }

        var board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        let memoryItems = board.items.filter { $0.cardKind == .memory }
        let pinnedTarget = try XCTUnwrap(memoryItems.last)
        try repository.updateHomeBoardItemPreference(pinnedTarget, action: .pin(true))

        board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        XCTAssertEqual(board.items.first?.compositionItem.itemKey, pinnedTarget.compositionItem.itemKey)
        XCTAssertTrue(board.items.first?.isPinned == true)

        let hiddenTarget = try XCTUnwrap(board.items.first { $0.cardKind == .memory && $0.compositionItem.itemKey != pinnedTarget.compositionItem.itemKey })
        try repository.updateHomeBoardItemPreference(hiddenTarget, action: .hide)

        board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        XCTAssertFalse(board.items.contains { $0.compositionItem.itemKey == hiddenTarget.compositionItem.itemKey })
    }

    func testHomeBoardUserOrderAndResizePersistAcrossRefreshes() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        for index in 1...3 {
            _ = try await repository.createMemory(
                from: MemoryCaptureDraft(
                    title: "Desktop memory \(index)",
                    rawText: "Desktop memory \(index) with Linh and planning.",
                    mood: "focused",
                    inputContext: "typed in debug",
                    captureSource: .composer,
                    artifacts: [.text(title: "Desktop memory \(index)", body: "Desktop memory \(index) with Linh and planning.")]
                )
            )
        }

        var board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        let memoryItems = board.items.filter { $0.cardKind == .memory }
        XCTAssertEqual(memoryItems.count, 3)

        try repository.updateHomeBoardItemPreference(memoryItems[0], action: .setUserOrder(30))
        try repository.updateHomeBoardItemPreference(memoryItems[1], action: .setUserOrder(10))
        try repository.updateHomeBoardItemPreference(memoryItems[2], action: .setUserOrder(20))
        try repository.updateHomeBoardItemPreference(memoryItems[1], action: .resize(HomeBoardSpan(widthColumns: 3, heightUnits: 2)))

        board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        let orderedKeys = board.userBoardItems.filter { $0.cardKind == .memory }.map(\.compositionItem.itemKey)
        XCTAssertEqual(orderedKeys, [
            memoryItems[1].compositionItem.itemKey,
            memoryItems[2].compositionItem.itemKey,
            memoryItems[0].compositionItem.itemKey,
        ])
        let resized = try XCTUnwrap(board.items.first { $0.compositionItem.itemKey == memoryItems[1].compositionItem.itemKey })
        XCTAssertEqual(resized.layout.span, HomeBoardSpan(widthColumns: 3, heightUnits: 2))
        XCTAssertEqual(resized.layout.layer, .userBoard)
    }

    func testHomeBoardMoveEarlierLaterNormalizesUserBoardOrder() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        for index in 1...3 {
            _ = try await repository.createMemory(
                from: MemoryCaptureDraft(
                    title: "Move memory \(index)",
                    rawText: "Move memory \(index) with Linh and planning.",
                    mood: "focused",
                    inputContext: "typed in debug",
                    captureSource: .composer,
                    artifacts: [.text(title: "Move memory \(index)", body: "Move memory \(index) with Linh and planning.")]
                )
            )
        }

        var board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        let initialItems = board.userBoardItems.filter { $0.cardKind == .memory }
        XCTAssertEqual(initialItems.count, 3)

        let moveEarlierUpdates = HomeBoardOrdering.updatesForMove(
            items: initialItems,
            moving: initialItems[2],
            direction: .earlier
        )
        XCTAssertEqual(moveEarlierUpdates.map { $0.item.compositionItem.itemKey }, [
            initialItems[0].compositionItem.itemKey,
            initialItems[2].compositionItem.itemKey,
            initialItems[1].compositionItem.itemKey,
        ])

        try repository.updateHomeBoardItemPreferences(
            moveEarlierUpdates.map { update in
                (item: update.item, action: .setUserOrder(update.sortIndex))
            }
        )

        board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        var orderedItems = board.userBoardItems.filter { $0.cardKind == .memory }
        XCTAssertEqual(orderedItems.map(\.compositionItem.itemKey), moveEarlierUpdates.map { $0.item.compositionItem.itemKey })
        XCTAssertEqual(orderedItems.compactMap(\.layout.userSortIndex), [10, 20, 30])

        let moveLaterUpdates = HomeBoardOrdering.updatesForMove(
            items: orderedItems,
            moving: orderedItems[0],
            direction: .later
        )
        try repository.updateHomeBoardItemPreferences(
            moveLaterUpdates.map { update in
                (item: update.item, action: .setUserOrder(update.sortIndex))
            }
        )

        board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        orderedItems = board.userBoardItems.filter { $0.cardKind == .memory }
        XCTAssertEqual(orderedItems.map(\.compositionItem.itemKey), moveLaterUpdates.map { $0.item.compositionItem.itemKey })
        XCTAssertTrue(HomeBoardOrdering.updatesForMove(items: orderedItems, moving: orderedItems[0], direction: .earlier).isEmpty)
        XCTAssertTrue(HomeBoardOrdering.updatesForMove(items: orderedItems, moving: orderedItems[2], direction: .later).isEmpty)
    }

    func testHomeBoardSuggestionsDoNotReplaceUserBoardWhenLimitIsFull() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Pinned desktop memory",
                rawText: "Pinned desktop memory with Linh.",
                mood: "focused",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Pinned desktop memory", body: "Pinned desktop memory with Linh.")]
            )
        )

        var board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        let memory = try XCTUnwrap(board.items.first { $0.cardKind == .memory })
        try repository.updateHomeBoardItemPreference(memory, action: .pin(true))

        board = try repository.fetchHomeBoard(for: Date(), limit: 1)
        XCTAssertEqual(board.items.count, 1)
        XCTAssertEqual(board.items.first?.compositionItem.itemKey, memory.compositionItem.itemKey)
        XCTAssertTrue(board.items.first?.isPinned == true)
        XCTAssertTrue(board.suggestionItems.isEmpty)
    }

    func testHomeBoardDismissedSuggestionStaysDismissed() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Suggestion desktop memory",
                rawText: "Suggestion desktop memory with Linh.",
                mood: "focused",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Suggestion desktop memory", body: "Suggestion desktop memory with Linh.")]
            )
        )

        var board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        let suggestion = try XCTUnwrap(board.suggestionItems.first { $0.cardKind == .systemPrompt })
        try repository.updateHomeBoardItemPreference(suggestion, action: .dismiss)

        board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        XCTAssertFalse(board.items.contains { $0.compositionItem.itemKey == suggestion.compositionItem.itemKey })
    }

    func testHomeBoardAcceptedSuggestionMovesIntoUserLayer() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Accepted suggestion memory",
                rawText: "Accepted suggestion memory with Linh.",
                mood: "focused",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Accepted suggestion memory", body: "Accepted suggestion memory with Linh.")]
            )
        )

        var board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        let suggestion = try XCTUnwrap(board.suggestionItems.first { $0.cardKind == .systemPrompt })
        XCTAssertEqual(suggestion.layout.layer, .suggestion)
        XCTAssertNil(suggestion.layout.acceptedAt)

        try repository.updateHomeBoardItemPreference(suggestion, action: .addToBoard)

        board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        let accepted = try XCTUnwrap(board.items.first { $0.compositionItem.itemKey == suggestion.compositionItem.itemKey })
        XCTAssertEqual(accepted.layout.layer, .userBoard)
        XCTAssertNotNil(accepted.layout.acceptedAt)
        XCTAssertFalse(board.suggestionItems.contains { $0.compositionItem.itemKey == suggestion.compositionItem.itemKey })
        XCTAssertTrue(board.userBoardItems.contains { $0.compositionItem.itemKey == suggestion.compositionItem.itemKey })
        XCTAssertEqual(accepted.layout.span, suggestion.layout.span)
    }

    func testHomeBoardSuggestionFeedbackAdjustsSuggestionPriorityWithoutTakingOwnership() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        for index in 1...2 {
            _ = try await repository.createMemory(
                from: MemoryCaptureDraft(
                    title: "Cafe context \(index)",
                    rawText: "Cafe context \(index) with Linh.",
                    mood: "focused",
                    inputContext: "typed in debug",
                    captureSource: .composer,
                    artifacts: [
                        .text(title: "Cafe context \(index)", body: "Cafe context \(index) with Linh."),
                        .location(
                            title: index == 1 ? "Cafe" : "Cafe station entrance",
                            summary: "Cafe near the station",
                            latitude: index == 1 ? 31.2 : 31.2004,
                            longitude: index == 1 ? 121.4 : 121.4003
                        )
                    ]
                )
            )
        }

        var board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        let cluster = try XCTUnwrap(board.suggestionItems.first { $0.cardKind == .contextCluster })
        let systemPrompt = try XCTUnwrap(board.suggestionItems.first { $0.cardKind == .systemPrompt })
        XCTAssertEqual(cluster.layout.layer, .suggestion)
        XCTAssertEqual(cluster.layout.feedbackAdjustment, 0)

        try repository.updateHomeBoardItemPreference(cluster, action: .preferLess)

        board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        var adjustedCluster = try XCTUnwrap(board.suggestionItems.first { $0.compositionItem.itemKey == cluster.compositionItem.itemKey })
        let systemPromptIndex = try XCTUnwrap(board.suggestionItems.firstIndex { $0.compositionItem.itemKey == systemPrompt.compositionItem.itemKey })
        let clusterIndex = try XCTUnwrap(board.suggestionItems.firstIndex { $0.compositionItem.itemKey == cluster.compositionItem.itemKey })
        XCTAssertEqual(adjustedCluster.layout.layer, .suggestion)
        XCTAssertEqual(adjustedCluster.layout.feedbackAdjustment, -18)
        XCTAssertLessThan(adjustedCluster.priority, cluster.priority)
        XCTAssertLessThan(systemPromptIndex, clusterIndex)
        XCTAssertFalse(board.userBoardItems.contains { $0.compositionItem.itemKey == cluster.compositionItem.itemKey })

        try repository.updateHomeBoardItemPreference(adjustedCluster, action: .preferMore)
        board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        adjustedCluster = try XCTUnwrap(board.suggestionItems.first { $0.compositionItem.itemKey == cluster.compositionItem.itemKey })
        XCTAssertEqual(adjustedCluster.layout.feedbackAdjustment, -6)

        try repository.updateHomeBoardItemPreference(adjustedCluster, action: .resetFeedback)
        board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        adjustedCluster = try XCTUnwrap(board.suggestionItems.first { $0.compositionItem.itemKey == cluster.compositionItem.itemKey })
        XCTAssertEqual(adjustedCluster.layout.feedbackAdjustment, 0)
        XCTAssertEqual(adjustedCluster.layout.layer, .suggestion)
    }

    func testHomeBoardDismissesSystemPromptAndLimitsSuggestedReflections() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "First board memory",
                rawText: "First board memory with Linh and planning.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "First board memory", body: "First board memory with Linh and planning.")]
            )
        )

        var board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        let systemPrompt = try XCTUnwrap(board.items.first { $0.cardKind == .systemPrompt })
        try repository.updateHomeBoardItemPreference(systemPrompt, action: .dismiss)
        board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        XCTAssertFalse(board.items.contains { $0.compositionItem.itemKey == systemPrompt.compositionItem.itemKey })

        for index in 1...4 {
            let memory = try await repository.createMemory(
                from: MemoryCaptureDraft(
                    title: "Reflection limit \(index)",
                    rawText: "Reflection limit \(index) with Linh and planning in the same rhythm.",
                    mood: "reflective",
                    inputContext: "typed in debug",
                    captureSource: .composer,
                    artifacts: [.text(title: "Reflection limit \(index)", body: "Reflection limit \(index) with Linh and planning in the same rhythm.")]
                )
            )
            try await repository.refreshMemoryPipeline(recordID: memory.record.id)
        }

        board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        XCTAssertLessThanOrEqual(board.items.filter { $0.cardKind == .reflection }.count, 2)
        XCTAssertFalse(board.items.contains { item in
            if case let .reflection(reflection) = item.renderValue {
                return reflection.status != .suggested
            }
            return false
        })
    }

    func testFetchHomeBoardUsesSuggestedReflectionsAndIgnoresSavedOnlyReflections() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Reflection source",
                rawText: "Walked with Linh in the rain and clarified the quarter planning priorities.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Reflection source", body: "Walked with Linh in the rain and clarified the quarter planning priorities.")]
            )
        )
        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Reflection source repeat",
                rawText: "Another walk with Linh brought the same quarter planning rhythm back into focus.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Reflection source repeat", body: "Another walk with Linh brought the same quarter planning rhythm back into focus.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        var board = try repository.fetchHomeBoard(for: Date(), limit: 8)
        let suggestedReflection = try XCTUnwrap(board.items.compactMap { item -> ReflectionSnapshot? in
            if case let .reflection(reflection) = item.renderValue { return reflection }
            return nil
        }.first)
        XCTAssertEqual(suggestedReflection.status, .suggested)

        for reflection in try repository.fetchReflections(limit: nil) where reflection.status == .suggested {
            try await repository.saveReflection(reflectionID: reflection.id)
        }
        board = try repository.fetchHomeBoard(for: Date(), limit: 8)

        XCTAssertFalse(board.items.contains {
            if case .reflection = $0.renderValue { return true }
            return false
        })
    }

    func testFetchHomeBoardIncludesArcAndReflectionItemsAfterPipeline() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let firstMemory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Rain walk",
                rawText: "Walked with Linh in the rain and clarified the quarter planning priorities.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Rain walk", body: "Walked with Linh in the rain and clarified the quarter planning priorities.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: firstMemory.record.id)
        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Rain walk repeat",
                rawText: "A second rainy walk with Linh returned to the same quarter planning priorities.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Rain walk repeat", body: "A second rainy walk with Linh returned to the same quarter planning priorities.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        let board = try repository.fetchHomeBoard(for: Date(), limit: 8)

        XCTAssertTrue(board.items.contains {
            if case .arc = $0.renderValue { return true }
            return false
        })
        XCTAssertTrue(board.items.contains {
            if case .reflection = $0.renderValue { return true }
            return false
        })
    }

    func testSingleLowSignalMemoryDoesNotGenerateArcOrReflection() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: LowSignalRecordAnalysisService(),
            cloudIntelligenceService: LowSignalCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Photo",
                rawText: "",
                mood: nil,
                inputContext: "photo capture",
                captureSource: .photo,
                artifacts: [.photo(title: "Photo", summary: "OCR", filename: "noise.jpg", imageData: nil, thumbnailData: nil, ocrText: "OCR")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        XCTAssertTrue(try repository.fetchTemporalArcSummaries(limit: nil).isEmpty)
        XCTAssertTrue(try repository.fetchReflectionSummaries(limit: nil).isEmpty)
        XCTAssertTrue(try repository.fetchGraphOverview(limitPerKind: 10, edgeLimit: 10).entitySections.allSatisfy { section in
            section.entities.allSatisfy { entity in
                !["theme", "OCR", "ORC", "photo", "image"].contains(entity.displayName)
            }
        })
    }

    func testTwoRelatedMemoriesCanGenerateArc() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let first = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning walk one",
                rawText: "Walked with Linh and reviewed quarter planning priorities.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Planning walk one", body: "Walked with Linh and reviewed quarter planning priorities.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: first.record.id)
        let second = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning walk two",
                rawText: "Another walk with Linh pushed the same planning theme further.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Planning walk two", body: "Another walk with Linh pushed the same planning theme further.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: second.record.id)

        let arcs = try repository.fetchTemporalArcSummaries(limit: 10)
        let arc = try XCTUnwrap(arcs.first)
        XCTAssertEqual(Set(arc.arc.sourceRecordIDs).count, 2)
        XCTAssertTrue(arc.arc.sourceRecordIDs.contains(second.record.id))
    }

    func testQualityTuningRunCreatesRealMemoryAndReport() async throws {
        let previousEnabled = QualityTuningRuntime.isEnabled
        let previousProfile = QualityTuningRuntime.promptProfile
        let previousThresholds = QualityTuningRuntime.thresholds
        defer {
            QualityTuningRuntime.isEnabled = previousEnabled
            QualityTuningRuntime.promptProfile = previousProfile
            QualityTuningRuntime.thresholds = previousThresholds
        }

        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )
        let request = QualityTuningRunRequest(
            scenario: .preset(.ordinaryShortText),
            promptProfile: .strict,
            thresholds: .defaults
        )

        let report = try await repository.runQualityTuningScenario(request)

        XCTAssertEqual(report.promptProfile, .strict)
        XCTAssertEqual(report.recordIDs.count, 1)
        XCTAssertFalse(report.requestBody.isEmpty)
        XCTAssertFalse(report.rawResponseBody.isEmpty)
        XCTAssertTrue(report.storedSummary.contains("artifacts:"))
        XCTAssertEqual(try repository.fetchRecentMemories(limit: nil).count, 1)
    }

    func testFetchGraphOverviewReturnsPeopleThemesAndEdgesFromGraphLayer() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Dinner plan",
                rawText: "Met Linh after dinner and mapped the next quarter plan.",
                mood: "focused",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Dinner plan", body: "Met Linh after dinner and mapped the next quarter plan.")]
            )
        )
        let latestMemory = try XCTUnwrap(repository.fetchRecentMemories(limit: 1).first)
        try await repository.refreshMemoryPipeline(recordID: latestMemory.record.id)

        let themes = try repository.fetchThemeSummaries(limit: 10)
        let overview = try repository.fetchGraphOverview(limitPerKind: 10, edgeLimit: 10)

        XCTAssertFalse(themes.isEmpty)
        XCTAssertTrue(themes.contains(where: { $0.entity.kind == .theme && $0.entity.displayName == "planning" }))
        XCTAssertTrue(overview.entitySections.contains(where: { $0.kind == .person && $0.entities.contains(where: { $0.displayName == "Linh" }) }))
        XCTAssertTrue(overview.entitySections.contains(where: { $0.kind == .theme && $0.entities.contains(where: { $0.displayName == "planning" }) }))
        XCTAssertFalse(overview.topEdges.isEmpty)
    }

    func testDetailArcAndReflectionQueriesReturnLinkedSnapshots() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let firstMemory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Late train insight",
                rawText: "Missed the express home after dinner with Linh and the quarter plan clicked into place.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Late train insight", body: "Missed the express home after dinner with Linh and the quarter plan clicked into place.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: firstMemory.record.id)
        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Late train insight repeat",
                rawText: "Another quiet walk with Linh made the same quarter planning pattern visible again.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Late train insight repeat", body: "Another quiet walk with Linh made the same quarter planning pattern visible again.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        let detail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        let arcSummaries = try repository.fetchTemporalArcSummaries(limit: 10)
        let reflectionSummaries = try repository.fetchReflectionSummaries(limit: 10)

        XCTAssertNotNil(detail.analysis)
        XCTAssertFalse(detail.entities.isEmpty)
        XCTAssertFalse(detail.edges.isEmpty)
        XCTAssertFalse(detail.arcs.isEmpty)
        XCTAssertFalse(detail.reflections.isEmpty)

        let matchingArc = try XCTUnwrap(arcSummaries.first(where: { $0.arc.sourceRecordIDs.contains(memory.record.id) }))
        XCTAssertFalse(matchingArc.relatedMemories.isEmpty)
        XCTAssertEqual(matchingArc.relatedMemories.first?.record.id, memory.record.id)
        XCTAssertNotNil(matchingArc.linkedReflection)

        let matchingReflection = try XCTUnwrap(
            reflectionSummaries.first(where: {
                $0.reflection.sourceRecordIDs.contains(memory.record.id) ||
                $0.linkedArc?.sourceRecordIDs.contains(memory.record.id) == true
            })
        )
        XCTAssertFalse(matchingReflection.relatedMemories.isEmpty)
    }

    func testEntityDetailReturnsRelatedMemoriesThemesArcsAndReflections() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let firstMemory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Quarter planning walk",
                rawText: "Walked home with Linh in the rain and clarified the quarter planning priorities.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Quarter planning walk", body: "Walked home with Linh in the rain and clarified the quarter planning priorities.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: firstMemory.record.id)
        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Quarter planning follow-up",
                rawText: "A follow-up walk with Linh kept returning to the same planning priorities.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Quarter planning follow-up", body: "A follow-up walk with Linh kept returning to the same planning priorities.")]
            )
        )
        let latestMemory = try XCTUnwrap(repository.fetchRecentMemories(limit: 1).first)
        try await repository.refreshMemoryPipeline(recordID: latestMemory.record.id)

        let people = try repository.fetchEntityDetails(kind: .person, limit: 10)
        let person = try XCTUnwrap(people.first(where: { $0.entity.displayName == "Linh" }))

        XCTAssertFalse(person.relatedMemories.isEmpty)
        XCTAssertTrue(person.relatedThemes.contains("planning"))
        XCTAssertFalse(person.relatedArcs.isEmpty)
        XCTAssertFalse(person.relatedReflections.isEmpty)
        XCTAssertFalse(person.edges.isEmpty)
    }

    func testGraphUpdaterPreservesAliasesAndProvenance() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: AliasRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Alias memory",
                rawText: "Dinner with Linh Tran clarified the quarter planning priorities.",
                mood: "focused",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Alias memory", body: "Dinner with Linh Tran clarified the quarter planning priorities.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        let person = try XCTUnwrap(repository.fetchEntityDetails(kind: .person, limit: 10).first)
        XCTAssertTrue(person.entity.aliases.contains(where: { $0 == "Linh Tran" }))
        XCTAssertTrue(person.entity.provenanceRecordIDs.contains(memory.record.id))

        let detail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        XCTAssertTrue(detail.entities.contains(where: { $0.aliases.contains("Linh Tran") }))
    }

    func testAnalysisGraphUpdatePersistsAnalysisEntitiesAndLinksWithoutLocationArtifact() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Text-only planning",
                rawText: "Linh and I clarified planning priorities in a text-only note.",
                mood: "focused",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Text-only planning", body: "Linh and I clarified planning priorities in a text-only note.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        let textArtifactID = try XCTUnwrap(repository.fetchArtifacts(recordID: memory.record.id).first(where: { $0.kind == .text })?.id)
        let context = container.mainContext
        let nodes = try context.fetch(FetchDescriptor<EntityNodeStore>())
        let person = try XCTUnwrap(nodes.first { $0.kindRawValue == EntityKind.person.rawValue && $0.displayName == "Linh" })
        let theme = try XCTUnwrap(nodes.first { $0.kindRawValue == EntityKind.theme.rawValue && $0.displayName == "planning" })

        XCTAssertTrue(person.provenanceRecordIDs.contains(memory.record.id))
        XCTAssertTrue(theme.provenanceRecordIDs.contains(memory.record.id))

        let links = try context.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        XCTAssertTrue(links.contains { $0.artifactID == textArtifactID && $0.entityID == person.id && $0.source == "analysis" })
        XCTAssertTrue(links.contains { $0.artifactID == textArtifactID && $0.entityID == theme.id && $0.source == "analysis" })

        let edges = try context.fetch(FetchDescriptor<EntityEdgeStore>())
        XCTAssertTrue(edges.contains {
            $0.sourceRecordIDs.contains(memory.record.id)
                && Set([$0.fromEntityID, $0.toEntityID]) == Set([person.id, theme.id])
        })
    }

    func testSearchReturnsFormalObjectSnapshots() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let firstMemory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning dinner",
                rawText: "Dinner with Linh turned into a planning session for the next quarter.",
                mood: "focused",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Planning dinner", body: "Dinner with Linh turned into a planning session for the next quarter.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: firstMemory.record.id)
        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning dinner repeat",
                rawText: "Another dinner with Linh circled back to the same planning session and quarter priorities.",
                mood: "focused",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Planning dinner repeat", body: "Another dinner with Linh circled back to the same planning session and quarter priorities.")]
            )
        )
        let latestMemory = try XCTUnwrap(repository.fetchRecentMemories(limit: 1).first)
        try await repository.refreshMemoryPipeline(recordID: latestMemory.record.id)

        let result = try repository.search(query: "planning", limit: 10)

        XCTAssertFalse(result.memories.isEmpty)
        XCTAssertTrue(result.memories.contains { memory in
            memory.explanations.contains { $0.source == .record || $0.source == .artifact || $0.source == .entity }
        })
        XCTAssertFalse(result.entities.isEmpty)
        XCTAssertFalse(result.arcs.isEmpty)
        XCTAssertFalse(result.reflections.isEmpty)
        XCTAssertTrue(result.entities.contains(where: { $0.entity.kind == .theme || $0.entity.kind == .person }))
        XCTAssertTrue(result.arcs.contains(where: { !$0.summary.relatedMemories.isEmpty }))
        XCTAssertTrue(result.reflections.contains(where: { !$0.summary.relatedMemories.isEmpty }))
    }

    func testMemoryLibraryFiltersByArtifactStatusContextInsightAndDateGroups() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let contextMemory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Context planning walk",
                rawText: "Walked with Linh and reviewed planning priorities.",
                captureSource: .composer,
                artifacts: [
                    .text(title: "Context planning walk", body: "Walked with Linh and reviewed planning priorities."),
                    .location(title: "Cafe", summary: "Cafe near the station", latitude: 31.2, longitude: 121.4),
                    .weather(condition: "Cloudy", temperatureCelsius: 22, humidity: 0.6, windSpeedKmh: 8, uvIndex: 2),
                    .music(trackName: "Dreams", artistName: "Fleetwood Mac", albumName: "Rumours", durationSeconds: 257, artworkURL: nil)
                ]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: contextMemory.record.id)

        let photoMemory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Photo memory",
                rawText: "Photo memory from the planning board.",
                captureSource: .photo,
                artifacts: [.photo(title: "Board photo", summary: "Planning board", filename: "board.jpg", imageData: nil, thumbnailData: nil, ocrText: "Planning board")]
            )
        )
        try repository.upsertPipelineStatus(
            MemoryPipelineStatusSnapshot(
                recordID: photoMemory.record.id,
                stage: .failed,
                requestID: nil,
                lastError: "network unavailable",
                requestBody: nil,
                responseBody: nil,
                rawErrorBody: nil,
                lastHTTPStatusCode: nil,
                failedStage: "analyze",
                lastAttemptAt: nil,
                completedAt: nil,
                updatedAt: Date.now
            )
        )

        let linkMemory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Article memory",
                rawText: "Saved a useful launch article.",
                captureSource: .composer,
                artifacts: [.link(title: "Launch notes", url: "https://example.com/launch", note: "Useful launch article")]
            )
        )
        let linkRecordID = linkMemory.record.id
        if let linkStore = try container.mainContext.fetch(
            FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == linkRecordID })
        ).first {
            linkStore.updatedAt = Date.now.addingTimeInterval(-36 * 60 * 60)
        }
        try container.mainContext.save()

        let all = try repository.fetchMemoryLibrary(filter: .empty, limit: nil)
        XCTAssertEqual(all.totalCount, 3)
        XCTAssertGreaterThanOrEqual(all.groups.count, 2)
        XCTAssertTrue(all.metadata.availableArtifactKinds.contains(.photo))
        XCTAssertTrue(all.metadata.availablePipelineStages.contains(.failed))

        let photoOnly = try repository.fetchMemoryLibrary(
            filter: MemoryLibraryFilter(artifactKinds: [.photo]),
            limit: nil
        )
        XCTAssertEqual(photoOnly.filteredCount, 1)
        XCTAssertEqual(photoOnly.groups.first?.rows.first?.memory.id, photoMemory.id)

        let failedOnly = try repository.fetchMemoryLibrary(
            filter: MemoryLibraryFilter(pipelineStages: [.failed]),
            limit: nil
        )
        XCTAssertEqual(failedOnly.filteredCount, 1)
        XCTAssertEqual(failedOnly.groups.first?.rows.first?.memory.id, photoMemory.id)

        let weatherOnly = try repository.fetchMemoryLibrary(
            filter: MemoryLibraryFilter(context: .hasWeather),
            limit: nil
        )
        XCTAssertEqual(weatherOnly.filteredCount, 1)
        XCTAssertEqual(weatherOnly.groups.first?.rows.first?.memory.id, contextMemory.id)

        let entityBacked = try repository.fetchMemoryLibrary(
            filter: MemoryLibraryFilter(insight: .hasEntities),
            limit: nil
        )
        XCTAssertTrue(entityBacked.groups.flatMap(\.rows).contains { $0.memory.id == contextMemory.id })
    }

    func testDeleteMemoryRemovesLibraryRowAndPublicInsightsDoNotKeepOrphanSources() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let first = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning walk one",
                rawText: "Walked with Linh and reviewed quarter planning priorities.",
                captureSource: .composer,
                artifacts: [.text(title: "Planning walk one", body: "Walked with Linh and reviewed quarter planning priorities.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: first.record.id)
        let second = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning walk two",
                rawText: "Another walk with Linh returned to the same quarter planning priorities.",
                captureSource: .composer,
                artifacts: [.text(title: "Planning walk two", body: "Another walk with Linh returned to the same quarter planning priorities.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: second.record.id)

        XCTAssertFalse(try repository.fetchInsightsPresentation(limitPerSection: 5).storylines.isEmpty)

        try repository.deleteMemory(recordID: second.record.id)

        let library = try repository.fetchMemoryLibrary(filter: .empty, limit: nil)
        XCTAssertFalse(library.groups.flatMap(\.rows).contains { $0.memory.id == second.record.id })

        let insights = try repository.fetchInsightsPresentation(limitPerSection: 10)
        XCTAssertFalse(insights.storylines.contains { $0.arc.sourceRecordIDs.contains(second.record.id) })
        XCTAssertFalse(insights.suggestedReflections.contains { $0.reflection.sourceRecordIDs.contains(second.record.id) })
        XCTAssertFalse(insights.people.contains { $0.relatedMemories.contains(where: { $0.id == second.record.id }) })
    }

    func testInsightsPresentationHighlightsStorylinesLimitsReflectionsAndFiltersOrphans() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let first = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Launch planning one",
                rawText: "Dinner with Linh turned into a planning session for the next quarter.",
                captureSource: .composer,
                artifacts: [.text(title: "Launch planning one", body: "Dinner with Linh turned into a planning session for the next quarter.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: first.record.id)
        let second = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Launch planning two",
                rawText: "Another dinner with Linh circled back to the same planning session and quarter priorities.",
                captureSource: .composer,
                artifacts: [.text(title: "Launch planning two", body: "Another dinner with Linh circled back to the same planning session and quarter priorities.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: second.record.id)

        let acceptedArc = try XCTUnwrap(repository.fetchTemporalArcSummaries(limit: 10).first)
        try await repository.acceptTemporalArc(arcID: acceptedArc.arc.id)

        let artifactID = try XCTUnwrap(try repository.fetchArtifacts(recordID: second.record.id).first?.id)
        let decision = EntityNode(
            kind: .decision,
            displayName: "Reduce launch scope",
            summary: "A concrete launch decision from the planning records.",
            provenanceRecordIDs: [second.record.id],
            createdAt: Date.now,
            updatedAt: Date.now,
            confidence: 0.91
        )
        try repository.upsert(entityNode: decision)
        try repository.upsert(artifactEntityLink: ArtifactEntityLink(
            artifactID: artifactID,
            entityID: decision.id,
            confidence: 0.91,
            source: "test",
            sourceRecordID: second.record.id,
            sourceAnalysisRecordID: second.record.id,
            createdAt: Date.now
        ))
        try repository.upsert(reflection: ReflectionSnapshot(
            type: .pattern,
            title: "Second suggested reflection",
            body: "A second suggested reflection that should be available to the presentation limit.",
            evidenceSummary: "planning",
            confidence: 0.72,
            status: .suggested,
            linkedTemporalArcID: acceptedArc.arc.id,
            sourceRecordIDs: [first.record.id, second.record.id],
            sourceArtifactIDs: [artifactID],
            sourceEntityIDs: [decision.id],
            createdAt: Date.now
        ))
        try repository.upsert(reflection: ReflectionSnapshot(
            type: .pattern,
            title: "Orphan reflection",
            body: "Should not appear publicly.",
            evidenceSummary: "missing",
            confidence: 0.99,
            status: .suggested,
            sourceRecordIDs: [UUID()],
            sourceArtifactIDs: [],
            createdAt: Date.now
        ))
        try repository.save()

        let snapshot = try repository.fetchInsightsPresentation(limitPerSection: 1)

        XCTAssertEqual(snapshot.highlightedStoryline?.arc.id, acceptedArc.arc.id)
        XCTAssertEqual(snapshot.storylines.count, 1)
        XCTAssertEqual(snapshot.suggestedReflections.count, 1)
        XCTAssertFalse(snapshot.suggestedReflections.contains { $0.reflection.title == "Orphan reflection" })
        XCTAssertFalse(snapshot.people.isEmpty)
        XCTAssertFalse(snapshot.places.isEmpty)
        XCTAssertFalse(snapshot.themes.isEmpty)
        XCTAssertTrue(snapshot.decisions.contains { $0.entity.displayName == "Reduce launch scope" })
    }

    func testCreateMemoryStillSucceedsWhenAnalysisHasNotRunYet() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: FailingRecordAnalysisService(),
            cloudIntelligenceService: FailingCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Offline save",
                rawText: "This should save even if analysis is unavailable.",
                mood: "steady",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Offline save", body: "This should save even if analysis is unavailable.")]
            )
        )

        XCTAssertEqual(memory.record.rawText, "This should save even if analysis is unavailable.")
        XCTAssertEqual(memory.pipelineStatus?.stage, .notScheduled)
        XCTAssertNil(try repository.fetchRecordAnalysis(recordID: memory.record.id))

        do {
            try await repository.refreshMemoryPipeline(recordID: memory.record.id)
            XCTFail("Expected refresh pipeline to fail when analysis service is unavailable")
        } catch {
            let status = try repository.fetchPipelineStatus(recordID: memory.record.id)
            XCTAssertEqual(status?.stage, .failed)
            XCTAssertNotNil(status?.lastError)
        }
    }

    func testUpdateMemoryPersistsCorrectionsAndAddsSupportingArtifact() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Draft note",
                rawText: "Initial wording that needs correction.",
                mood: "unclear",
                inputContext: "typed quickly",
                captureSource: .composer,
                artifacts: [.text(title: "Draft note", body: "Initial wording that needs correction.")]
            )
        )

        let updated = try await repository.updateMemory(
            recordID: memory.record.id,
            draft: MemoryEditDraft(
                rawText: "Corrected wording with clearer intent.",
                userMood: "focused",
                inputContext: "rewritten in detail",
                appendedArtifactText: "Follow-up note with one more concrete detail.",
                addedArtifacts: [
                    .link(title: "Reference", url: "https://example.com/detail", note: "Detail edit source")
                ]
            )
        )

        let detail = try XCTUnwrap(updated)
        XCTAssertEqual(detail.record.rawText, "Corrected wording with clearer intent.")
        XCTAssertEqual(detail.record.userMood, "focused")
        XCTAssertEqual(detail.record.inputContext, "rewritten in detail")
        let addedArtifact = try XCTUnwrap(detail.artifacts.first(where: { $0.summary == "Follow-up note with one more concrete detail." }))
        XCTAssertEqual(addedArtifact.kind, .document)
        XCTAssertEqual(addedArtifact.metadata["documentType"], "promptAnswer")
        XCTAssertNotNil(detail.artifactSemanticDigests.first(where: { $0.artifactID == addedArtifact.id }))
        let arrangement = try XCTUnwrap(detail.cardArrangement)
        XCTAssertTrue(arrangement.nodes.contains { node in
            if case let .artifact(id) = node.contentRef {
                return id == addedArtifact.id
            }
            return false
        })
        let addedLink = try XCTUnwrap(detail.artifacts.first(where: { $0.kind == .link }))
        XCTAssertEqual(addedLink.metadata["url"], "https://example.com/detail")
        XCTAssertNotNil(detail.artifactSemanticDigests.first(where: { $0.artifactID == addedLink.id }))
        XCTAssertEqual(detail.pipelineStatus?.stage, .notScheduled)
    }

    func testApplyMemoryMutationUpdatesRecordAndInvalidatesDerivedData() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Mutation source",
                rawText: "Original memory about Linh and launch planning.",
                mood: "unclear",
                inputContext: "before mutation",
                captureSource: .composer,
                artifacts: [.text(title: "Mutation source", body: "Original memory about Linh and launch planning.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)
        XCTAssertNotNil(try repository.fetchRecordAnalysis(recordID: memory.record.id))

        let result = try await repository.applyMemoryMutation(
            recordID: memory.record.id,
            mutation: MemoryMutationDraft(
                recordPatch: MemoryMutationRecordPatch(
                    rawText: .set("Rewritten memory about clearer launch planning."),
                    userMood: .set("focused"),
                    inputContext: .set(nil)
                )
            ),
            refreshPolicy: .saveOnly
        )

        let detail = try XCTUnwrap(result.detail)
        XCTAssertEqual(detail.record.rawText, "Rewritten memory about clearer launch planning.")
        XCTAssertEqual(detail.record.userMood, "focused")
        XCTAssertNil(detail.record.inputContext)
        XCTAssertEqual(result.addedArtifactIDs.count, 0)
        XCTAssertEqual(detail.artifacts.filter { $0.kind == .text }.count, 1)
        XCTAssertEqual(result.pipelineStatus?.stage, .notScheduled)
        XCTAssertTrue(result.invalidatedDerivedData)
        XCTAssertNil(try repository.fetchRecordAnalysis(recordID: memory.record.id))
    }

    func testApplyMemoryMutationAddsArtifactsAndPreservesRecordOrder() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Artifact mutation",
                rawText: "A memory that will receive artifacts.",
                captureSource: .composer,
                artifacts: [.text(title: "Artifact mutation", body: "A memory that will receive artifacts.")]
            )
        )

        let result = try await repository.applyMemoryMutation(
            recordID: memory.record.id,
            mutation: MemoryMutationDraft(
                addedArtifacts: [
                    .location(title: "Office", summary: "Shanghai Jing'an", latitude: 31.23, longitude: 121.47),
                    .todo(title: "Send recap", note: "Before Friday"),
                    .link(title: "Reference", url: "https://example.com/recap", note: "Source material")
                ]
            ),
            refreshPolicy: .saveOnly
        )

        let record = try XCTUnwrap(try repository.fetchRecordShell(id: memory.record.id))
        XCTAssertEqual(result.addedArtifactIDs.count, 3)
        XCTAssertEqual(record.artifactIDs.suffix(3), result.addedArtifactIDs[...])
        XCTAssertEqual(result.pipelineStatus?.stage, .notScheduled)

        let detail = try XCTUnwrap(result.detail)
        XCTAssertTrue(detail.artifacts.contains(where: { $0.kind == .location && $0.title == "Office" }))
        XCTAssertTrue(detail.artifacts.contains(where: { $0.kind == .todo && $0.title == "Send recap" }))
        XCTAssertTrue(detail.artifacts.contains(where: { $0.kind == .link && $0.metadata["url"] == "https://example.com/recap" }))
        XCTAssertEqual(
            Set(detail.artifactSemanticDigests.filter { result.addedArtifactIDs.contains($0.artifactID) }.map(\.artifactID)),
            Set(result.addedArtifactIDs)
        )
        let arrangement = try XCTUnwrap(detail.cardArrangement)
        let arrangedArtifactIDs = arrangement.nodes.flatMap { node -> [UUID] in
            switch node.contentRef {
            case let .artifact(id):
                return [id]
            case let .artifactGroup(ids, _):
                return ids
            case .recordBody, .affect, .journalingSuggestion:
                return []
            }
        }
        XCTAssertTrue(Set(result.addedArtifactIDs).isSubset(of: Set(arrangedArtifactIDs)))
    }

    func testApplyMemoryMutationPreservesUserArrangementSizeAndStack() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Preserve arrangement",
                rawText: "A memory with a user arranged desk.",
                captureSource: .composer,
                artifacts: [
                    .text(title: "Preserve arrangement", body: "A memory with a user arranged desk."),
                    .photo(title: "Photo", summary: "Photo summary", filename: "photo.jpg"),
                    .audio(title: "Voice", summary: "Audio summary", filename: "voice.caf", transcriptionText: "Audio transcript"),
                    .todo(title: "Follow up", note: "Keep this stacked")
                ]
            )
        )

        let initialDetail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        let photoID = try XCTUnwrap(initialDetail.artifacts.first(where: { $0.kind == .photo })?.id)
        let audioID = try XCTUnwrap(initialDetail.artifacts.first(where: { $0.kind == .audio })?.id)
        let todoID = try XCTUnwrap(initialDetail.artifacts.first(where: { $0.kind == .todo })?.id)
        let initialArrangement = try XCTUnwrap(initialDetail.cardArrangement)
        let userArrangement = initialArrangement
            .settingSize(.small, forArtifactID: photoID, updatedAt: Date.now)
            .stackingWithPrevious(artifactID: todoID, updatedAt: Date.now)

        _ = try await repository.applyMemoryMutation(
            recordID: memory.record.id,
            mutation: MemoryMutationDraft(
                artifactOrder: [photoID, audioID, todoID],
                cardArrangement: userArrangement
            ),
            refreshPolicy: .saveOnly
        )

        let result = try await repository.applyMemoryMutation(
            recordID: memory.record.id,
            mutation: MemoryMutationDraft(
                recordPatch: MemoryMutationRecordPatch(rawText: .set("A memory with preserved user arrangement.")),
                artifactOrder: [todoID, audioID, photoID]
            ),
            refreshPolicy: .saveOnly
        )

        let detail = try XCTUnwrap(result.detail)
        let arrangement = try XCTUnwrap(detail.cardArrangement)
        let photoNode = try XCTUnwrap(arrangement.nodes.first { node in
            if case let .artifact(id) = node.contentRef {
                return id == photoID
            }
            return false
        })
        XCTAssertEqual(photoNode.layout.size, .small)

        let stackedNode = try XCTUnwrap(arrangement.nodes.first { node in
            if case let .artifactGroup(ids, _) = node.contentRef {
                return ids == [audioID, todoID]
            }
            return false
        })
        XCTAssertEqual(stackedNode.visualRecipe, .bundlePacket)
        XCTAssertEqual(stackedNode.layout.size, .stack)
        XCTAssertFalse(arrangement.nodes.contains { node in
            if case let .artifact(id) = node.contentRef {
                return id == todoID
            }
            return false
        })
        XCTAssertEqual(result.pipelineStatus?.stage, .notScheduled)
    }

    func testApplyMemoryMutationArrangementOnlyPreservesAnalysisAndPipelineStatus() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Visual arrangement only",
                rawText: "A memory with analysis that should survive visual desk edits.",
                captureSource: .composer,
                artifacts: [
                    .text(title: "Visual arrangement only", body: "A memory with analysis that should survive visual desk edits."),
                    .photo(title: "Photo", summary: "Photo summary", filename: "photo.jpg"),
                    .todo(title: "Follow up", note: "Keep the plan")
                ]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        let analyzedDetail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        let originalUpdatedAt = analyzedDetail.record.updatedAt
        let photoID = try XCTUnwrap(analyzedDetail.artifacts.first(where: { $0.kind == .photo })?.id)
        let visualArrangement = try XCTUnwrap(analyzedDetail.cardArrangement)
            .settingSize(.small, forArtifactID: photoID, updatedAt: Date.now)
        XCTAssertEqual(analyzedDetail.pipelineStatus?.stage, .completed)
        XCTAssertNotNil(analyzedDetail.analysis)

        let result = try await repository.applyMemoryMutation(
            recordID: memory.record.id,
            mutation: MemoryMutationDraft(cardArrangement: visualArrangement),
            refreshPolicy: .saveOnly
        )

        XCTAssertFalse(result.invalidatedDerivedData)
        XCTAssertEqual(result.pipelineStatus?.stage, .completed)
        let detail = try XCTUnwrap(result.detail)
        XCTAssertNotNil(detail.analysis)
        XCTAssertEqual(detail.record.updatedAt, originalUpdatedAt)

        let arrangement = try XCTUnwrap(detail.cardArrangement)
        let photoNode = try XCTUnwrap(arrangement.nodes.first { node in
            if case let .artifact(id) = node.contentRef {
                return id == photoID
            }
            return false
        })
        XCTAssertEqual(photoNode.layout.size, .small)
    }

    func testApplyMemoryMutationUpdatesDeletesReordersAndPurgesGraphLinks() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Multi artifact",
                rawText: "A memory with several artifacts.",
                captureSource: .composer,
                artifacts: [
                    .text(title: "Original text", body: "A memory with several artifacts."),
                    .photo(title: "Photo", summary: "Photo summary", filename: "photo.jpg", imageData: nil, thumbnailData: nil),
                    .todo(title: "Todo", note: "Original todo")
                ]
            )
        )

        let initialDetail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        let text = try XCTUnwrap(initialDetail.artifacts.first(where: { $0.kind == .text }))
        let photo = try XCTUnwrap(initialDetail.artifacts.first(where: { $0.kind == .photo }))
        let todo = try XCTUnwrap(initialDetail.artifacts.first(where: { $0.kind == .todo }))
        let linkedEntity = EntityNode(
            kind: .theme,
            displayName: "Linked Theme",
            summary: "A link that should be purged by mutation.",
            provenanceRecordIDs: [memory.record.id],
            createdAt: Date.now,
            updatedAt: Date.now,
            confidence: 0.8
        )
        try repository.upsert(entityNode: linkedEntity)
        try repository.upsert(artifactEntityLink: ArtifactEntityLink(
            artifactID: text.id,
            entityID: linkedEntity.id,
            confidence: 0.8,
            source: "test",
            sourceRecordID: memory.record.id,
            sourceAnalysisRecordID: memory.record.id,
            createdAt: Date.now
        ))
        XCTAssertFalse(try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id)).entities.isEmpty)

        var updatedText = text
        updatedText.title = "Updated text"
        updatedText.summary = "Updated summary"
        updatedText.textContent = "Updated text content"
        updatedText.payload = .text("Updated text content")

        let result = try await repository.applyMemoryMutation(
            recordID: memory.record.id,
            mutation: MemoryMutationDraft(
                updatedArtifacts: [updatedText],
                deletedArtifactIDs: [photo.id],
                artifactOrder: [todo.id, text.id]
            ),
            refreshPolicy: .saveOnly
        )

        XCTAssertEqual(result.updatedArtifactIDs, [text.id])
        XCTAssertEqual(result.deletedArtifactIDs, [photo.id])
        XCTAssertEqual(result.reorderedArtifactIDs, [todo.id, text.id])

        let record = try XCTUnwrap(try repository.fetchRecordShell(id: memory.record.id))
        XCTAssertEqual(Array(record.artifactIDs.prefix(2)), [todo.id, text.id])
        XCTAssertFalse(record.artifactIDs.contains(photo.id))
        XCTAssertNil(try repository.fetchArtifact(id: photo.id))
        XCTAssertEqual(try repository.fetchArtifact(id: text.id)?.summary, "Updated summary")
        XCTAssertTrue(try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id)).entities.isEmpty)
    }

    func testApplyMemoryMutationRunImmediatelyRefreshesPipeline() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Immediate mutation",
                rawText: "A memory waiting for immediate refresh.",
                captureSource: .composer,
                artifacts: [.text(title: "Immediate mutation", body: "A memory waiting for immediate refresh.")]
            )
        )

        let result = try await repository.applyMemoryMutation(
            recordID: memory.record.id,
            mutation: MemoryMutationDraft(
                recordPatch: MemoryMutationRecordPatch(rawText: .set("A memory refreshed through mutation."))
            ),
            refreshPolicy: .runImmediately
        )

        XCTAssertEqual(result.detail?.record.rawText, "A memory refreshed through mutation.")
        XCTAssertEqual(result.pipelineStatus?.stage, .completed)
        XCTAssertNotNil(try repository.fetchRecordAnalysis(recordID: memory.record.id))
    }

    func testTodoCapturePersistsCanonicalTodoArtifactKind() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Call landlord",
                rawText: "Remember to call the landlord before Friday.",
                mood: "practical",
                inputContext: "typed in composer",
                captureSource: .composer,
                artifacts: [.todo(title: "Call landlord", note: "Before Friday")]
            )
        )

        let detail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        let todoArtifact = try XCTUnwrap(detail.artifacts.first)

        XCTAssertEqual(todoArtifact.kind, .todo)
        XCTAssertEqual(todoArtifact.title, "Call landlord")
        XCTAssertEqual(todoArtifact.metadata["todo"], "true")
    }

    func testQuickTextCaptureDraftPersistsTextMemoryAndPendingPipeline() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Quick hallway thought",
                rawText: "Met Alex after lunch and decided to revisit the launch copy.",
                mood: "focused",
                inputContext: "quick text capture",
                captureSource: .composer,
                artifacts: [.text(title: "Quick hallway thought", body: "Met Alex after lunch and decided to revisit the launch copy.")]
            )
        )

        let detail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        let textArtifact = try XCTUnwrap(detail.artifacts.first)

        XCTAssertEqual(detail.record.rawText, "Met Alex after lunch and decided to revisit the launch copy.")
        XCTAssertEqual(detail.record.inputContext, "quick text capture")
        XCTAssertEqual(textArtifact.kind, .text)
        XCTAssertEqual(textArtifact.summary, "Met Alex after lunch and decided to revisit the launch copy.")
        XCTAssertEqual(detail.pipelineStatus?.stage, .notScheduled)
    }

    func testQuickVoiceCaptureDraftPersistsAudioArtifactWithTranscript() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Protecting morning writing time",
                rawText: "I keep returning to protecting mornings for writing before meetings.",
                mood: nil,
                inputContext: "quick voice capture",
                captureSource: .audio,
                artifacts: [.audio(
                    title: "Voice note",
                    summary: "I keep returning to protecting mornings for writing before meetings.",
                    filename: "quick_voice.caf",
                    audioData: Data([1, 2, 3, 4]),
                    transcriptionText: "I keep returning to protecting mornings for writing before meetings."
                )]
            )
        )

        let detail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        let audioArtifact = try XCTUnwrap(detail.artifacts.first)

        XCTAssertEqual(detail.record.captureSource, .audio)
        XCTAssertEqual(detail.record.inputContext, "quick voice capture")
        XCTAssertEqual(audioArtifact.kind, .audio)
        XCTAssertEqual(audioArtifact.title, "Voice note")
        XCTAssertEqual(audioArtifact.mediaRef?.filename, "quick_voice.caf")
        XCTAssertEqual(audioArtifact.textContent, "I keep returning to protecting mornings for writing before meetings.")
        XCTAssertEqual(detail.pipelineStatus?.stage, .notScheduled)
    }

    func testVoiceComposerDraftKeepsTranscriptInTextArtifactAndAudioMetadata() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )
        let transcript = "I keep returning to protecting mornings for writing before meetings."

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: nil,
                rawText: transcript,
                mood: nil,
                inputContext: nil,
                captureSource: .audio,
                artifacts: [
                    .text(title: nil, body: transcript),
                    .audio(
                        title: "Voice note",
                        summary: "Audio capture",
                        filename: "quick_voice.caf",
                        audioData: Data([1, 2, 3, 4]),
                        transcriptionText: transcript
                    )
                ]
            )
        )

        let detail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        let textArtifact = try XCTUnwrap(detail.artifacts.first(where: { $0.kind == .text }))
        let audioArtifact = try XCTUnwrap(detail.artifacts.first(where: { $0.kind == .audio }))

        XCTAssertEqual(textArtifact.textContent, transcript)
        XCTAssertTrue(textArtifact.title.hasSuffix("..."))
        XCTAssertLessThanOrEqual(textArtifact.title.count, 51)
        XCTAssertEqual(audioArtifact.summary, "Audio capture")
        XCTAssertEqual(audioArtifact.textContent, "")
        XCTAssertEqual(audioArtifact.metadata["transcriptionText"], transcript)
    }

    func testQuickVoiceCaptureDraftCanPersistAudioWithoutTranscript() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Voice note",
                rawText: "Audio capture",
                mood: nil,
                inputContext: "quick voice capture",
                captureSource: .audio,
                artifacts: [.audio(
                    title: "Voice note",
                    summary: "Audio capture",
                    filename: "quiet_voice.caf",
                    audioData: Data([5, 6, 7]),
                    transcriptionText: ""
                )]
            )
        )

        let detail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        let audioArtifact = try XCTUnwrap(detail.artifacts.first)

        XCTAssertEqual(detail.record.rawText, "Audio capture")
        XCTAssertEqual(audioArtifact.kind, .audio)
        XCTAssertEqual(audioArtifact.summary, "Audio capture")
        XCTAssertEqual(audioArtifact.textContent, "Audio capture")
        XCTAssertEqual(audioArtifact.mediaRef?.filename, "quiet_voice.caf")
    }

    func testAppendContextArtifactsPersistsWeatherLocationMusicAndResetsPipeline() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Context memory",
                rawText: "A regular capture that should receive automatic context.",
                captureSource: .composer,
                artifacts: [.text(title: "Context memory", body: "A regular capture that should receive automatic context.")]
            )
        )

        let updated = try await repository.appendArtifacts(
            recordID: memory.record.id,
            drafts: [
                .location(title: "Office", summary: "Shanghai Jing'an", latitude: 31.23, longitude: 121.47),
                .weather(condition: "Cloudy", temperatureCelsius: 22, humidity: 0.65, windSpeedKmh: 12, uvIndex: 3, latitude: 31.23, longitude: 121.47),
                .music(trackName: "Intro", artistName: "The Band", albumName: "Morning", durationSeconds: 180, artworkURL: "https://example.com/art.jpg"),
            ]
        )

        XCTAssertEqual(updated?.artifactCount, 4)
        XCTAssertEqual(updated?.pipelineStatus?.stage, .notScheduled)

        let detail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        XCTAssertTrue(detail.artifacts.contains(where: { $0.kind == .location && $0.metadata["latitude"] == "31.23" }))
        XCTAssertTrue(detail.artifacts.contains(where: { $0.kind == .weather && $0.metadata["temperatureCelsius"] == "22.0" && $0.metadata["longitude"] == "121.47" }))
        XCTAssertTrue(detail.artifacts.contains(where: { $0.kind == .music && $0.metadata["artworkURL"] == "https://example.com/art.jpg" }))
    }

    func testCreateMemoryPersistsSelectedContextInInitialSnapshot() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Morning draft",
                rawText: "Protected the morning writing block.",
                captureSource: .composer,
                artifacts: [
                    .text(title: "Morning draft", body: "Protected the morning writing block."),
                    .location(title: "Desk", summary: "Home desk", latitude: 31.2, longitude: 121.4),
                    .weather(condition: "Clear", temperatureCelsius: 19, humidity: 0.4, windSpeedKmh: 6, uvIndex: 2),
                    .music(trackName: "Quiet", artistName: "Nils Frahm", albumName: "Solo", durationSeconds: 240, artworkURL: nil)
                ]
            )
        )

        try await repository.refreshMemoryPipeline(recordID: memory.record.id)
        let detail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))

        XCTAssertEqual(detail.artifacts.count, 4)
        XCTAssertEqual(Set(detail.artifacts.map(\.kind)), Set([.text, .location, .weather, .music]))
        XCTAssertNotNil(detail.analysis)
    }

    func testDeleteMemoryCascadesDerivedGraphArcReflectionData() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let first = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning one",
                rawText: "Walked with Linh and reviewed quarter planning priorities.",
                captureSource: .composer,
                artifacts: [.text(title: "Planning one", body: "Walked with Linh and reviewed quarter planning priorities.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: first.record.id)
        let second = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning two",
                rawText: "Another walk with Linh returned to the same quarter planning priorities.",
                captureSource: .composer,
                artifacts: [.text(title: "Planning two", body: "Another walk with Linh returned to the same quarter planning priorities.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: second.record.id)

        let secondArtifactIDs = try repository.fetchArtifacts(recordID: second.record.id).map(\.id)
        XCTAssertFalse(try repository.fetchTemporalArcSummaries(limit: nil).isEmpty)
        XCTAssertFalse(try repository.fetchReflectionSummaries(limit: nil).isEmpty)

        try repository.deleteMemory(recordID: second.record.id)

        XCTAssertNil(try repository.fetchMemoryDetail(recordID: second.record.id))
        XCTAssertNil(try repository.fetchRecordAnalysis(recordID: second.record.id))
        XCTAssertNil(try repository.fetchPipelineStatus(recordID: second.record.id))
        XCTAssertTrue(try repository.fetchArtifacts(recordID: second.record.id).isEmpty)

        let context = container.mainContext
        XCTAssertFalse(try context.fetch(FetchDescriptor<ArtifactEntityLinkStore>()).contains { link in
            secondArtifactIDs.contains(link.artifactID)
                || link.sourceRecordID == second.record.id
                || link.sourceAnalysisRecordID == second.record.id
        })
        XCTAssertFalse(try context.fetch(FetchDescriptor<EntityEdgeStore>()).contains { edge in
            edge.sourceRecordIDs.contains(second.record.id)
                || edge.sourceArtifactIDs.contains { secondArtifactIDs.contains($0) }
        })
        XCTAssertFalse(try context.fetch(FetchDescriptor<TemporalArcStore>()).contains { arc in
            arc.sourceRecordIDs.contains(second.record.id)
                || arc.sourceArtifactIDs.contains { secondArtifactIDs.contains($0) }
        })
        XCTAssertFalse(try context.fetch(FetchDescriptor<ReflectionSnapshotStore>()).contains { reflection in
            reflection.sourceRecordIDs.contains(second.record.id)
                || reflection.sourceArtifactIDs.contains { secondArtifactIDs.contains($0) }
        })
        XCTAssertFalse(try context.fetch(FetchDescriptor<EntityNodeStore>()).contains { entity in
            entity.provenanceRecordIDs.contains(second.record.id)
        })
    }

    func testRefreshMemoryPipelinePurgesStaleDerivedDataBeforeRerun() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: TextDrivenRecordAnalysisService(),
            cloudIntelligenceService: TextDrivenCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Ava plan",
                rawText: "Ava helped shape the plan.",
                captureSource: .composer,
                artifacts: [.text(title: "Ava plan", body: "Ava helped shape the plan.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)
        XCTAssertTrue(try repository.fetchPeopleSummaries(limit: nil).contains { $0.entity.displayName == "Ava" })

        _ = try await repository.updateMemory(
            recordID: memory.record.id,
            draft: MemoryEditDraft(
                rawText: "Ben helped reshape the launch decision.",
                userMood: "focused",
                inputContext: "rewritten",
                appendedArtifactText: nil
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        let people = try repository.fetchPeopleSummaries(limit: nil)
        XCTAssertFalse(people.contains { $0.entity.displayName == "Ava" })
        XCTAssertEqual(people.filter { $0.entity.displayName == "Ben" }.count, 1)
        XCTAssertEqual(try repository.fetchTemporalArcSummaries(limit: nil).count, 0)
        XCTAssertEqual(try repository.fetchReflectionSummaries(limit: nil).count, 1)
    }

    func testProductGraphQueriesFilterLegacyOrphanArcsReflectionsAndPeople() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )
        let now = Date.now

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Valid source",
                rawText: "Linh and planning stayed connected.",
                captureSource: .composer,
                artifacts: [.text(title: "Valid source", body: "Linh and planning stayed connected.")]
            )
        )
        let validArtifactID = try XCTUnwrap(try repository.fetchArtifacts(recordID: memory.record.id).first?.id)
        let validEntity = EntityNode(
            kind: .person,
            displayName: "Valid Person",
            provenanceRecordIDs: [memory.record.id],
            createdAt: now,
            updatedAt: now,
            confidence: 0.9
        )
        let orphanEntity = EntityNode(
            kind: .person,
            displayName: "Orphan Person",
            provenanceRecordIDs: [UUID()],
            createdAt: now,
            updatedAt: now,
            confidence: 0.9
        )
        try repository.upsert(entityNode: validEntity)
        try repository.upsert(entityNode: orphanEntity)
        try repository.upsert(artifactEntityLink: ArtifactEntityLink(
            artifactID: validArtifactID,
            entityID: validEntity.id,
            confidence: 0.9,
            source: "test",
            sourceRecordID: memory.record.id,
            sourceAnalysisRecordID: memory.record.id,
            createdAt: now
        ))
        try repository.upsert(temporalArc: TemporalArc(
            title: "Valid arc",
            summary: "Valid",
            status: .candidate,
            sourceRecordIDs: [memory.record.id],
            sourceArtifactIDs: [validArtifactID],
            sourceEntityIDs: [validEntity.id],
            startDate: now,
            endDate: now,
            intensityScore: 0.8,
            clusterStrength: 0.8,
            createdAt: now,
            updatedAt: now
        ))
        let missingRecordID = UUID()
        try repository.upsert(temporalArc: TemporalArc(
            title: "Orphan arc",
            summary: "Orphan",
            status: .candidate,
            sourceRecordIDs: [memory.record.id, missingRecordID],
            sourceArtifactIDs: [validArtifactID],
            sourceEntityIDs: [orphanEntity.id],
            startDate: now,
            endDate: now,
            intensityScore: 0.8,
            clusterStrength: 0.8,
            createdAt: now,
            updatedAt: now
        ))
        try repository.upsert(reflection: ReflectionSnapshot(
            type: .pattern,
            title: "Orphan reflection",
            body: "Should not be visible.",
            evidenceSummary: "missing source",
            confidence: 0.8,
            status: .suggested,
            sourceRecordIDs: [missingRecordID],
            sourceArtifactIDs: [],
            createdAt: now
        ))
        try repository.save()

        XCTAssertEqual(try repository.fetchTemporalArcs(limit: nil).count, 2)
        XCTAssertEqual(try repository.fetchTemporalArcSummaries(limit: nil).map(\.arc.title), ["Valid arc"])
        XCTAssertTrue(try repository.fetchReflectionSummaries(limit: nil).isEmpty)
        XCTAssertFalse(try repository.fetchPeopleSummaries(limit: nil).contains { $0.entity.displayName == "Orphan Person" })
    }

    func testLinkCapturePersistsMetadataSummaryAndPreviewPayload() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )
        let preview = Data([0x01, 0x02, 0x03])

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: nil,
                rawText: "Useful article",
                captureSource: .composer,
                artifacts: [
                    .link(
                        title: "Extracted page title",
                        url: "https://example.com/article",
                        note: "Useful article",
                        summary: "Example Blog",
                        metadata: ["siteName": "Example Blog", "ogImage": "https://example.com/og.jpg"],
                        thumbnailData: preview
                    )
                ]
            )
        )

        let detail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        let link = try XCTUnwrap(detail.artifacts.first(where: { $0.kind == .link }))

        XCTAssertEqual(link.title, "Extracted page title")
        XCTAssertEqual(link.summary, "Example Blog")
        XCTAssertEqual(link.textContent, "Example Blog\nUseful article")
        XCTAssertEqual(link.metadata["url"], "https://example.com/article")
        XCTAssertEqual(link.metadata["siteName"], "Example Blog")
        XCTAssertEqual(link.metadata["ogImage"], "https://example.com/og.jpg")
        XCTAssertEqual(link.previewPayload, preview)
    }

    func testMergeTemporalArcReturnsMergedDetailAndArchivesCandidate() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let first = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning walk one",
                rawText: "Walked with Linh and reviewed quarter planning priorities.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Planning walk one", body: "Walked with Linh and reviewed quarter planning priorities.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: first.record.id)

        let second = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning walk two",
                rawText: "Another rainy walk with Linh pushed the same planning theme further.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Planning walk two", body: "Another rainy walk with Linh pushed the same planning theme further.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: second.record.id)

        let third = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning walk three",
                rawText: "A third check-in with Linh connected the same planning theme to launch scope.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Planning walk three", body: "A third check-in with Linh connected the same planning theme to launch scope.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: third.record.id)

        let arcsBefore = try repository.fetchTemporalArcSummaries(limit: 10)
        let sourceArc = try XCTUnwrap(arcsBefore.first(where: { $0.arc.sourceRecordIDs.contains(first.record.id) }))
        XCTAssertNotNil(try repository.fetchTemporalArcDetail(arcID: sourceArc.arc.id)?.mergeCandidate)

        let mergedDetail = try await repository.mergeTemporalArc(arcID: sourceArc.arc.id)
        let detail = try XCTUnwrap(mergedDetail)

        XCTAssertTrue(detail.summary.arc.sourceRecordIDs.contains(first.record.id))
        XCTAssertTrue(detail.summary.arc.sourceRecordIDs.contains(second.record.id))
        XCTAssertNil(detail.mergeCandidate)
        XCTAssertTrue(detail.reflections.count >= 1)
    }

    func testReflectionMutationsPersistStatusChanges() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Reflection note",
                rawText: "Dinner with Linh turned into a planning session with reflective value.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Reflection note", body: "Dinner with Linh turned into a planning session with reflective value.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        let reflection = try XCTUnwrap(repository.fetchReflectionSummaries(limit: 10).first)

        try await repository.saveReflection(reflectionID: reflection.reflection.id)
        XCTAssertEqual(try repository.fetchReflectionDetail(reflectionID: reflection.reflection.id)?.summary.reflection.status, .saved)

        try await repository.dismissReflection(reflectionID: reflection.reflection.id)
        XCTAssertEqual(try repository.fetchReflectionDetail(reflectionID: reflection.reflection.id)?.summary.reflection.status, .dismissed)

        try await repository.archiveReflection(reflectionID: reflection.reflection.id)
        XCTAssertEqual(try repository.fetchReflectionDetail(reflectionID: reflection.reflection.id)?.summary.reflection.status, .archived)
    }

    func testClearDebugFixturesDoesNotDeleteRealRecords() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Real memory",
                rawText: "A real saved memory.",
                mood: "steady",
                inputContext: "real user capture",
                captureSource: .composer,
                artifacts: [.text(title: "Real memory", body: "A real saved memory.")]
            )
        )
        _ = try await repository.seedDebugFixtures(count: 1)

        try repository.clearDebugFixtures()

        let remaining = try repository.fetchRecentMemories(limit: nil)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.record.inputContext, "real user capture")
    }

    func testFetchDebugDiagnosticsReturnsPersistedPipelineTrace() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Trace memory",
                rawText: "Trace this analysis request.",
                mood: "focused",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Trace memory", body: "Trace this analysis request.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        let diagnostics = try repository.fetchDebugDiagnostics(targetType: .memory, targetID: memory.record.id)
        XCTAssertEqual(diagnostics.pipelineTrace?.statusCode, 200)
        // Analysis pipeline: requestBody is the JSON-encoded AnalysisRequestPayload.
        XCTAssertNotNil(diagnostics.analyzePayload?.requestBody)
        XCTAssertTrue(diagnostics.analyzePayload?.requestBody.contains("client_request_id") == true)
        XCTAssertFalse(diagnostics.analyzePayload?.requestBody.contains("schema_version") == true)
        // Analysis pipeline: responseBody is the JSON-encoded AnalysisResponseEnvelope (contains "analysis" key).
        XCTAssertNotNil(diagnostics.analyzePayload?.responseBody)
        XCTAssertTrue(diagnostics.analyzePayload?.responseBody.contains("analysis") == true)
    }

    func testRerunDebugPipelineModesResolveCorrectTargets() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let firstMemory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Rerun memory",
                rawText: "Dinner with Linh turned into another planning moment.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Rerun memory", body: "Dinner with Linh turned into another planning moment.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: firstMemory.record.id)
        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Rerun memory repeat",
                rawText: "Another dinner with Linh repeated the same planning moment.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Rerun memory repeat", body: "Another dinner with Linh repeated the same planning moment.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        try await repository.rerunDebugPipeline(targetType: .memory, targetID: memory.record.id, mode: .analysisOnly)
        let arc = try XCTUnwrap(repository.fetchTemporalArcSummaries(limit: 1).first)
        try await repository.rerunDebugPipeline(targetType: .arc, targetID: arc.arc.id, mode: .graphArcReflection)
        let reflection = try XCTUnwrap(repository.fetchReflectionSummaries(limit: 1).first)
        try await repository.rerunDebugPipeline(targetType: .reflection, targetID: reflection.reflection.id, mode: .reflectionReplay)

        XCTAssertNotNil(try repository.fetchPipelineStatus(recordID: memory.record.id))
    }

    func testReflectionReplayUsesReflectionContractTrace() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService(),
            cloudIntelligenceService: StubCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Replay memory",
                rawText: "Dinner with Linh clarified the quarter planning pattern.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Replay memory", body: "Dinner with Linh clarified the quarter planning pattern.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)
        let reflection = try XCTUnwrap(repository.fetchReflectionSummaries(limit: 1).first)

        try await repository.rerunDebugPipeline(targetType: .reflection, targetID: reflection.reflection.id, mode: .reflectionReplay)
        let diagnostics = try repository.fetchDebugDiagnostics(targetType: .reflection, targetID: reflection.reflection.id)

        XCTAssertEqual(diagnostics.reflectionPayload?.requestBody, "{\"mode\":\"reflection_replay\"}")
        XCTAssertEqual(diagnostics.reflectionPayload?.responseBody, "{\"body\":\"Replay reflection body\"}")
        XCTAssertEqual(diagnostics.reflectionPayload?.lastError, nil)
        XCTAssertEqual(diagnostics.reflectionPayload?.rawErrorBody, nil)
    }

    func testAnalysisFailurePersistsPipelineTraceForDiagnostics() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: FailingRecordAnalysisService(),
            cloudIntelligenceService: FailingCompositionCloudService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Failing trace",
                rawText: "The analysis will fail here.",
                mood: "uneasy",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Failing trace", body: "The analysis will fail here.")]
            )
        )

        await XCTAssertThrowsErrorAsync {
            try await repository.refreshMemoryPipeline(recordID: memory.record.id)
        }

        let status = try XCTUnwrap(repository.fetchPipelineStatus(recordID: memory.record.id))
        let diagnostics = try repository.fetchDebugDiagnostics(targetType: .memory, targetID: memory.record.id)

        XCTAssertEqual(status.stage, .failed)
        XCTAssertEqual(status.lastHTTPStatusCode, 503)
        XCTAssertEqual(status.failedStage, "analysis")
        XCTAssertEqual(diagnostics.pipelineTrace?.rawErrorBody, "{\"error\":\"analysis unavailable\"}")
        XCTAssertEqual(diagnostics.analyzePayload?.rawErrorBody, "{\"error\":\"analysis unavailable\"}")
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: @escaping () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected async throw", file: file, line: line)
    } catch {
    }
}

private struct StubRecordAnalysisService: ReflectionAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: "Stub summary",
            themes: ["planning"],
            emotionInterpretation: "reflective",
            salienceScore: 0.86,
            retrievalTerms: ["planning", "rain"],
            entityMentions: [
                EntityReference(kind: .person, name: "Linh", confidence: 0.9),
                EntityReference(kind: .theme, name: "planning", confidence: 0.8),
                EntityReference(kind: .place, name: "Rain Walk", confidence: 0.7),
            ],
            candidateEdges: [
                CandidateEntityEdge(
                    from: EntityReference(kind: .person, name: "Linh", confidence: 0.9),
                    to: EntityReference(kind: .theme, name: "planning", confidence: 0.8),
                    relationKind: .relatedTo,
                    confidence: 0.75
                )
            ],
            followUpCandidates: [],
            reflectionHint: "Watch for repeated planning moments.",
            createdAt: record.updatedAt
        )
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        DebugPipelineTraceSnapshot(
            requestID: nil,
            requestBody: "{\"analysis_reason\":\"capture_ingest\"}",
            responseBody: "{\"summary\":\"Stub summary\"}",
            rawErrorBody: nil,
            statusCode: 200,
            failedStage: nil
        )
    }

    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        ReflectionServiceResult(
            title: "Generated reflection",
            body: "This planning pattern has enough evidence to be worth reviewing because it connects a concrete memory, a repeated person, and a clear decision-making theme.",
            evidenceSummary: artifacts.map(\.summary).joined(separator: " | "),
            confidence: 0.76,
            sourceRecordIDs: [record.id],
            debugTrace: DebugPipelineTraceSnapshot(
                requestID: nil,
                requestBody: "{\"mode\":\"reflection_generate\"}",
                responseBody: "{\"body\":\"Generated reflection body\"}",
                rawErrorBody: nil,
                statusCode: 200,
                failedStage: nil
            )
        )
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        ReflectionServiceResult(
            title: "Replay reflection",
            body: "Replay reflection body",
            evidenceSummary: prompt ?? reflection.body,
            confidence: 0.58,
            sourceRecordIDs: reflection.sourceRecordIDs,
            debugTrace: DebugPipelineTraceSnapshot(
                requestID: nil,
                requestBody: "{\"mode\":\"reflection_replay\"}",
                responseBody: "{\"body\":\"Replay reflection body\"}",
                rawErrorBody: nil,
                statusCode: 200,
                failedStage: nil
            )
        )
    }
}

private struct TextDrivenRecordAnalysisService: ReflectionAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        let personName = record.rawText.localizedCaseInsensitiveContains("Ben") ? "Ben" : "Ava"
        return RecordAnalysisSnapshot(
            recordID: record.id,
            summary: "\(personName) helped with a concrete planning decision.",
            themes: ["planning"],
            emotionInterpretation: "focused",
            salienceScore: 0.9,
            retrievalTerms: ["planning", personName.lowercased()],
            entityMentions: [
                EntityReference(kind: .person, name: personName, confidence: 0.95),
                EntityReference(kind: .theme, name: "planning", confidence: 0.9),
            ],
            candidateEdges: [
                CandidateEntityEdge(
                    from: EntityReference(kind: .person, name: personName, confidence: 0.95),
                    to: EntityReference(kind: .theme, name: "planning", confidence: 0.9),
                    relationKind: .relatedTo,
                    confidence: 0.82
                )
            ],
            followUpCandidates: [],
            reflectionHint: "Notice whether this planning decision repeats.",
            createdAt: record.updatedAt
        )
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        DebugPipelineTraceSnapshot(
            requestID: nil,
            requestBody: "{\"analysis_reason\":\"capture_ingest\"}",
            responseBody: "{\"summary\":\"Text-driven summary\"}",
            rawErrorBody: nil,
            statusCode: 200,
            failedStage: nil
        )
    }

    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        ReflectionServiceResult(
            title: "Planning decision reflection",
            body: "This planning decision is concrete enough to revisit without inventing unrelated context.",
            evidenceSummary: artifacts.map(\.summary).joined(separator: " | "),
            confidence: 0.82,
            sourceRecordIDs: [record.id],
            debugTrace: nil
        )
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        ReflectionServiceResult(
            title: reflection.title,
            body: reflection.body,
            evidenceSummary: reflection.evidenceSummary,
            confidence: reflection.confidence,
            sourceRecordIDs: reflection.sourceRecordIDs,
            debugTrace: nil
        )
    }
}

private struct FailingRecordAnalysisService: ReflectionAnalysisServing {
    struct StubError: LocalizedError {
        var errorDescription: String? { "Analysis service unavailable." }
    }

    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        throw StubError()
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        DebugPipelineTraceSnapshot(
            requestID: nil,
            requestBody: "{\"analysis_reason\":\"capture_ingest\"}",
            responseBody: nil,
            rawErrorBody: "{\"error\":\"analysis unavailable\"}",
            statusCode: 503,
            failedStage: "analysis"
        )
    }

    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw StubError()
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw StubError()
    }
}

private struct LowSignalRecordAnalysisService: ReflectionAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: "Low signal photo.",
            themes: ["theme", "OCR"],
            emotionInterpretation: "neutral",
            salienceScore: 0.2,
            retrievalTerms: ["OCR", "photo"],
            entityMentions: [
                EntityReference(kind: .theme, name: "theme", confidence: 0.99),
                EntityReference(kind: .theme, name: "OCR", confidence: 0.99),
                EntityReference(kind: .object, name: "photo", confidence: 0.99),
            ],
            candidateEdges: [],
            followUpCandidates: [],
            reflectionHint: "",
            createdAt: record.updatedAt
        )
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        DebugPipelineTraceSnapshot(
            requestID: nil,
            requestBody: "{\"analysis_reason\":\"capture_ingest\"}",
            responseBody: "{\"summary\":\"Low signal photo\"}",
            rawErrorBody: nil,
            statusCode: 200,
            failedStage: nil
        )
    }

    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        XCTFail("Low signal memories should not request reflection generation.")
        return ReflectionServiceResult(
            title: "Unexpected",
            body: "Unexpected",
            evidenceSummary: "",
            confidence: 0,
            sourceRecordIDs: [record.id],
            debugTrace: nil
        )
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        ReflectionServiceResult(
            title: "Replay",
            body: "Replay",
            evidenceSummary: "",
            confidence: 0,
            sourceRecordIDs: reflection.sourceRecordIDs,
            debugTrace: nil
        )
    }
}

private struct AliasRecordAnalysisService: ReflectionAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: "Alias summary",
            themes: ["planning"],
            emotionInterpretation: "focused",
            salienceScore: 0.86,
            retrievalTerms: ["planning", "linh"],
            entityMentions: [
                EntityReference(kind: .person, name: "Linh", aliases: ["Linh Tran"], confidence: 0.92),
                EntityReference(kind: .theme, name: "planning", confidence: 0.81),
            ],
            candidateEdges: [
                CandidateEntityEdge(
                    from: EntityReference(kind: .person, name: "Linh", aliases: ["Linh Tran"], confidence: 0.92),
                    to: EntityReference(kind: .theme, name: "planning", confidence: 0.81),
                    relationKind: .relatedTo,
                    confidence: 0.76
                )
            ],
            followUpCandidates: [],
            reflectionHint: "Track whether Linh and planning keep co-occurring.",
            createdAt: record.updatedAt
        )
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        DebugPipelineTraceSnapshot(
            requestID: nil,
            requestBody: "{\"analysis_reason\":\"capture_ingest\"}",
            responseBody: "{\"summary\":\"Alias summary\"}",
            rawErrorBody: nil,
            statusCode: 200,
            failedStage: nil
        )
    }

    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        ReflectionServiceResult(
            title: "Alias reflection",
            body: "This alias planning pattern has enough evidence to be worth reviewing because it connects a concrete memory, a repeated person, and a clear decision-making theme.",
            evidenceSummary: artifacts.map(\.summary).joined(separator: " | "),
            confidence: 0.76,
            sourceRecordIDs: [record.id],
            debugTrace: DebugPipelineTraceSnapshot(
                requestID: nil,
                requestBody: "{\"mode\":\"reflection_generate\"}",
                responseBody: "{\"body\":\"Alias reflection body\"}",
                rawErrorBody: nil,
                statusCode: 200,
                failedStage: nil
            )
        )
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        ReflectionServiceResult(
            title: "Alias replay",
            body: "Alias replay body",
            evidenceSummary: prompt ?? reflection.body,
            confidence: 0.57,
            sourceRecordIDs: reflection.sourceRecordIDs,
            debugTrace: DebugPipelineTraceSnapshot(
                requestID: nil,
                requestBody: "{\"mode\":\"reflection_replay\"}",
                responseBody: "{\"body\":\"Alias replay body\"}",
                rawErrorBody: nil,
                statusCode: 200,
                failedStage: nil
            )
        )
    }
}

@MainActor
final class AuthSessionManagerTests: XCTestCase {
    func testAppleSignInFallsBackToLocalSessionWhenServerAuthFails() async throws {
        let store = KeychainCredentialStore(account: "mory-auth-test-\(UUID().uuidString)", inMemory: true)
        defer { Task { try? await store.delete() } }

        AuthURLProtocol.responseHandler = { request in
            XCTAssertEqual(request.url?.path, "/auth/apple")
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"error":"apple audience mismatch"}"#.utf8))
        }
        defer { AuthURLProtocol.responseHandler = nil }

        let manager = AuthSessionManager(
            credentialStore: store,
            apiClient: makeAuthTestClient()
        )

        let didComplete = await manager.didSignIn(identityToken: "header.payload.signature", userID: "apple-user-123")
        let credential = await store.loadCredential()
        let diagnostics = await manager.fetchDiagnostics()

        XCTAssertTrue(didComplete)
        XCTAssertEqual(manager.state, .authenticated)
        XCTAssertEqual(credential?.userID, "apple-user-123")
        XCTAssertEqual(credential?.accessToken, "")
        XCTAssertEqual(credential?.identityToken, "header.payload.signature")
        XCTAssertEqual(diagnostics.lastHTTPStatusCode, 401)
        XCTAssertEqual(diagnostics.lastFailedStage, "auth_apple")
        XCTAssertTrue(diagnostics.lastResponseBody?.contains("apple audience mismatch") == true)
    }

    func testCheckSessionRestoresLocalAppleCredentialWithoutServerToken() async throws {
        let store = KeychainCredentialStore(account: "mory-auth-test-\(UUID().uuidString)", inMemory: true)
        defer { Task { try? await store.delete() } }

        try await store.saveCredential(
            AuthCredential(
                accessToken: "",
                refreshToken: "",
                expiresAt: nil,
                userID: "apple-user-123",
                identityToken: "stored-identity-token"
            )
        )

        let manager = AuthSessionManager(
            credentialStore: store,
            apiClient: makeAuthTestClient()
        )

        await manager.checkSession()
        let diagnostics = await manager.fetchDiagnostics()

        XCTAssertEqual(manager.state, .authenticated)
        XCTAssertEqual(diagnostics.userID, "apple-user-123")
        XCTAssertFalse(diagnostics.hasAccessToken)
        XCTAssertTrue(diagnostics.hasIdentityToken)
        XCTAssertEqual(diagnostics.lastEvent, "Restored local Apple session without server token")
    }

    func testAppleSignInPersistsServerCredentialWhenServerAuthSucceeds() async throws {
        let store = KeychainCredentialStore(account: "mory-auth-test-\(UUID().uuidString)", inMemory: true)
        defer { Task { try? await store.delete() } }

        AuthURLProtocol.responseHandler = { request in
            XCTAssertEqual(request.url?.path, "/auth/apple")
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let body = Data(
                #"""
                {
                  "access_token": "access-token",
                  "refresh_token": "refresh-token",
                  "expires_at": "2099-01-01T00:00:00Z",
                  "user": {
                    "id": "server-user-123",
                    "tier": "seed"
                  }
                }
                """#.utf8
            )
            return (response, body)
        }
        defer { AuthURLProtocol.responseHandler = nil }

        let manager = AuthSessionManager(
            credentialStore: store,
            apiClient: makeAuthTestClient()
        )

        let didComplete = await manager.didSignIn(identityToken: "identity-token", userID: "apple-user-123")
        let credential = await store.loadCredential()

        XCTAssertTrue(didComplete)
        XCTAssertEqual(manager.state, .authenticated)
        XCTAssertEqual(credential?.userID, "server-user-123")
        XCTAssertEqual(credential?.accessToken, "access-token")
        XCTAssertEqual(credential?.refreshToken, "refresh-token")
        XCTAssertEqual(credential?.identityToken, "identity-token")
    }

    func testSessionExpiredEventClearsCredentialAndReturnsToLogin() async throws {
        let store = KeychainCredentialStore(account: "mory-auth-test-\(UUID().uuidString)", inMemory: true)
        defer { Task { try? await store.delete() } }
        try await store.saveCredential(
            AuthCredential(
                accessToken: "expired-access",
                refreshToken: "expired-refresh",
                expiresAt: Date(timeIntervalSince1970: 0),
                userID: "server-user-123",
                identityToken: nil
            )
        )

        let manager = AuthSessionManager(
            credentialStore: store,
            apiClient: makeAuthTestClient()
        )
        await manager.checkSession()
        await manager.handleSessionExpired(reason: "Refresh token expired.")

        XCTAssertEqual(manager.state, .unauthenticated)
        let credential = await store.loadCredential()
        XCTAssertNil(credential)
        let diagnostics = await manager.fetchDiagnostics()
        XCTAssertEqual(diagnostics.lastEvent, "Session expired")
        XCTAssertEqual(diagnostics.lastError, "Refresh token expired.")
    }

    func testTokenProviderRefresh401ClearsCredentialAndPostsSessionExpired() async throws {
        let store = KeychainCredentialStore(account: "mory-auth-test-\(UUID().uuidString)", inMemory: true)
        defer { Task { try? await store.delete() } }
        try await store.saveCredential(
            AuthCredential(
                accessToken: "expired-access",
                refreshToken: "expired-refresh",
                expiresAt: Date(timeIntervalSince1970: 0),
                userID: "server-user-123",
                identityToken: nil
            )
        )

        AuthURLProtocol.responseHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/refresh")
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"error":"refresh expired"}"#.utf8))
        }
        defer { AuthURLProtocol.responseHandler = nil }

        let expired = expectation(description: "session expired notification")
        let token = NotificationCenter.default.addObserver(
            forName: .moryAuthSessionExpired,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertEqual(notification.userInfo?[MoryAuthSessionExpiredUserInfoKey.reason] as? String, "Refresh token expired.")
            expired.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let provider = MoryAuthTokenProvider(
            apiClient: makeAuthTestClient(),
            credentialStore: store
        )
        do {
            _ = try await provider.accessToken()
            XCTFail("Expected unauthorized refresh failure.")
        } catch MoryAPIClient.APIError.unauthorized {
            // Expected.
        }

        await fulfillment(of: [expired], timeout: 1)
        let credential = await store.loadCredential()
        XCTAssertNil(credential)
    }

    private func makeAuthTestClient() -> MoryAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthURLProtocol.self]
        return MoryAPIClient(
            configuration: MoryAPIConfiguration(baseURL: URL(string: "https://auth.test")!),
            session: URLSession(configuration: configuration)
        )
    }
}

private final class AuthURLProtocol: URLProtocol {
    static var responseHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let responseHandler = Self.responseHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try responseHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Composition Cloud Service Stubs

/// Standard stub mirrors the legacy composition analysis fixture through the Analysis cloud contract.
private struct StubCompositionCloudService: CloudIntelligenceServing {
    func analyzeMemory(_ payload: AnalysisRequestPayload) async throws -> AnalysisResponseEnvelope {
        AnalysisResponseEnvelope(
            analysis: AnalysisRecordResponse(
                tags: ["planning"],
                retrievalTerms: ["planning", "rain"],
                emotion: .init(label: "reflective", intensity: 0.6, confidence: 0.7, interpretation: nil),
                entities: [
                    .init(kind: "person", name: "Linh", canonicalName: "Linh", aliases: ["Linh Tran"], confidence: 0.92, sourceArtifactIDs: []),
                    .init(kind: "theme", name: "planning", canonicalName: "planning", aliases: nil, confidence: 0.81, sourceArtifactIDs: []),
                    .init(kind: "place", name: "Rain Walk", canonicalName: "Rain Walk", aliases: nil, confidence: 0.7, sourceArtifactIDs: [])
                ],
                candidateEdges: [
                    .init(
                        fromName: "Linh",
                        fromKind: "person",
                        toName: "planning",
                        toKind: "theme",
                        relation: "related_to",
                        confidence: 0.75
                    )
                ],
                insight: "Composition stub summary.",
                summary: "Composition stub summary.",
                salienceScore: 0.86,
                followUp: nil,
                reflectionHint: "Watch for repeated planning moments."
            ),
            affectProposals: [],
            graphDeltaProposals: [],
            profileUpdateProposals: [],
            mergeSplitCandidates: [],
            arcCandidates: [],
            reflectionCandidates: [
                .init(
                    candidateID: nil,
                    title: "Stub reflection",
                    body: "Planning keeps recurring with Linh — worth revisiting.",
                    evidenceSummary: "Derived from stub analysis.",
                    confidence: 0.7,
                    sourceRecordIDs: [payload.recordShell.id],
                    sourceArtifactIDs: [],
                    sourceEntityIDs: []
                )
            ],
            questionCandidates: [],
            quality: .init(confidence: 0.7, uncertaintyReasons: [], needsUserCheck: [])
        )
    }
    func refineTranscript(_ p: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse { throw CompositionStubError.unsupported }
    func suggestQuestions(_ p: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse { throw CompositionStubError.unsupported }
    func suggestChapters(_ p: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse { throw CompositionStubError.unsupported }
    func analyzePhotoSemantics(_ p: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse { throw CompositionStubError.unsupported }
    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse { throw CompositionStubError.unsupported }
}

/// Low-signal stub: returns noisy theme/OCR/photo entities that EntityQualityPolicy filters.
/// No arcs or reflections.
private struct LowSignalCompositionCloudService: CloudIntelligenceServing {
    func analyzeMemory(_ payload: AnalysisRequestPayload) async throws -> AnalysisResponseEnvelope {
        AnalysisResponseEnvelope(
            analysis: AnalysisRecordResponse(
                tags: ["theme", "OCR"],
                retrievalTerms: ["OCR", "photo"],
                emotion: .init(label: "neutral", intensity: 0.2, confidence: 0.3, interpretation: nil),
                entities: [
                    .init(kind: "theme", name: "theme", canonicalName: "theme", aliases: nil, confidence: 0.99, sourceArtifactIDs: []),
                    .init(kind: "theme", name: "OCR", canonicalName: "OCR", aliases: nil, confidence: 0.99, sourceArtifactIDs: []),
                    .init(kind: "object", name: "photo", canonicalName: "photo", aliases: nil, confidence: 0.99, sourceArtifactIDs: [])
                ],
                candidateEdges: [],
                insight: "Low signal photo.",
                summary: "Low signal photo.",
                salienceScore: 0.2,
                followUp: nil,
                reflectionHint: nil
            ),
            affectProposals: [],
            graphDeltaProposals: [],
            profileUpdateProposals: [],
            mergeSplitCandidates: [],
            arcCandidates: [],
            reflectionCandidates: [],
            questionCandidates: [],
            quality: .init(confidence: 0.3, uncertaintyReasons: ["thin_context"], needsUserCheck: [])
        )
    }
    func refineTranscript(_ p: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse { throw CompositionStubError.unsupported }
    func suggestQuestions(_ p: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse { throw CompositionStubError.unsupported }
    func suggestChapters(_ p: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse { throw CompositionStubError.unsupported }
    func analyzePhotoSemantics(_ p: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse { throw CompositionStubError.unsupported }
    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse { throw CompositionStubError.unsupported }
}

/// Text-driven stub: returns Ava or Ben based on payload rawText (mirrors TextDrivenRecordAnalysisService).
/// Returns one reflection candidate so refresh-purge-rerun tests get count == 1.
private struct TextDrivenCompositionCloudService: CloudIntelligenceServing {
    func analyzeMemory(_ payload: AnalysisRequestPayload) async throws -> AnalysisResponseEnvelope {
        let rawText = payload.recordShell.rawText
        let personName = rawText.localizedCaseInsensitiveContains("Ben") ? "Ben" : "Ava"
        return AnalysisResponseEnvelope(
            analysis: AnalysisRecordResponse(
                tags: ["planning"],
                retrievalTerms: ["planning", personName.lowercased()],
                emotion: .init(label: "focused", intensity: 0.6, confidence: 0.7, interpretation: nil),
                entities: [
                    .init(kind: "person", name: personName, canonicalName: personName, aliases: nil, confidence: 0.9, sourceArtifactIDs: [])
                ],
                candidateEdges: [],
                insight: "\(personName) helped with a concrete planning decision.",
                summary: "\(personName) helped with a concrete planning decision.",
                salienceScore: 0.8,
                followUp: nil,
                reflectionHint: nil
            ),
            affectProposals: [],
            graphDeltaProposals: [],
            profileUpdateProposals: [],
            mergeSplitCandidates: [],
            arcCandidates: [],
            reflectionCandidates: [
                .init(
                    candidateID: nil,
                    title: "Text-driven reflection",
                    body: "\(personName) helped shape a decision worth revisiting.",
                    evidenceSummary: "Derived from text analysis.",
                    confidence: 0.7,
                    sourceRecordIDs: [payload.recordShell.id],
                    sourceArtifactIDs: [],
                    sourceEntityIDs: []
                )
            ],
            questionCandidates: [],
            quality: .init(confidence: 0.7, uncertaintyReasons: [], needsUserCheck: [])
        )
    }
    func refineTranscript(_ p: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse { throw CompositionStubError.unsupported }
    func suggestQuestions(_ p: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse { throw CompositionStubError.unsupported }
    func suggestChapters(_ p: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse { throw CompositionStubError.unsupported }
    func analyzePhotoSemantics(_ p: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse { throw CompositionStubError.unsupported }
    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse { throw CompositionStubError.unsupported }
}

/// Failing stub: throws from analyzeMemory and exposes 503/analysis debug info.
private struct FailingCompositionCloudService: CloudIntelligenceServing, CloudIntelligenceDebugging {
    struct FailError: LocalizedError {
        var errorDescription: String? { "Analysis service unavailable." }
    }
    func analyzeMemory(_ payload: AnalysisRequestPayload) async throws -> AnalysisResponseEnvelope {
        throw FailError()
    }
    func latestCloudDebugError() async -> MoryAPIClient.DebugErrorSnapshot? {
        MoryAPIClient.DebugErrorSnapshot(
            requestID: nil,
            statusCode: 503,
            responseBody: nil,
            rawErrorBody: "{\"error\":\"analysis unavailable\"}",
            failedStage: "analysis",
            errorDescription: "Analysis service unavailable."
        )
    }
    func latestCloudDebugRequestID() async -> String? { nil }
    func refineTranscript(_ p: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse { throw CompositionStubError.unsupported }
    func suggestQuestions(_ p: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse { throw CompositionStubError.unsupported }
    func suggestChapters(_ p: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse { throw CompositionStubError.unsupported }
    func analyzePhotoSemantics(_ p: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse { throw CompositionStubError.unsupported }
    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse { throw CompositionStubError.unsupported }
}

private enum CompositionStubError: Error { case unsupported }
