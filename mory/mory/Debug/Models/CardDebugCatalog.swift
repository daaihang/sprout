import Foundation

struct CardDebugContentFixture: Identifiable, Hashable {
    var id: String { contentKind.rawValue }
    let contentKind: MemoryCardContentKind
    let item: CaptureCardItem
    let preferredDensity: MemoryCardContentDensity
    let layerNotes: [String]
}

struct CardDebugTypeCatalogEntry: Identifiable, Hashable {
    var id: String { contentType }
    let contentType: String
    let fixture: CardDebugContentFixture
    let draftLayer: String
    let artifactLayer: String
    let digestLayer: String
    let arrangementLayer: String
}

struct CardDebugContentDensityFixture: Identifiable, Hashable {
    var id: String {
        "\(fixture.contentKind.rawValue)-\(density.rawValue)"
    }

    let fixture: CardDebugContentFixture
    let density: MemoryCardContentDensity

    var metrics: MemoryCardObjectMetrics {
        MemoryCardObjectMetrics.resolve(
            contentKind: fixture.contentKind,
            density: density,
            mediaAspectRatio: fixture.item.payload.mediaAspectRatio
        )
    }
}

enum CardDebugCatalog {
    static let contentFixtures: [CardDebugContentFixture] = [
        CardDebugContentFixture(
            contentKind: .recordBody,
            item: CaptureCardItem(
                id: "debug-kind-record-body",
                payload: .prompt(CapturePromptCardPayload(prompt: "What should be remembered?", answer: "A quiet morning note with the core record body.")),
                origin: .manual,
                title: "Record body",
                detail: "A quiet morning note with the core record body.",
                metadata: "recordBody"
            ),
            preferredDensity: .detailed,
            layerNotes: ["contentRef=.recordBody", "ArtifactKind.text is folded into RecordShell.rawText", "density=.detailed"]
        ),
        CardDebugContentFixture(
            contentKind: .prompt,
            item: CaptureCardItem(
                id: "debug-kind-prompt",
                payload: .prompt(CapturePromptCardPayload(prompt: "What question shaped this memory?", answer: "The answer card keeps prompt context separate from the record body.")),
                origin: .manual,
                title: "Prompt answer",
                detail: "The answer card keeps prompt context separate from the record body.",
                metadata: "promptAnswer"
            ),
            preferredDensity: .detailed,
            layerNotes: ["CaptureArtifactContent.promptAnswer", "ArtifactKind.text/document", "density=.detailed"]
        ),
        CardDebugContentFixture(
            contentKind: .photo,
            item: CaptureCardItem(
                id: "debug-kind-photo",
                payload: .photo(CapturePhotoCardPayload(
                    mediaDimensions: ArtifactMediaDimensions(width: 1440, height: 1800),
                    photoCount: 1
                )),
                origin: .manual,
                title: "Kitchen light",
                detail: "Media-only photo card; text stays in artifact facts, not on the card.",
                metadata: "photo.jpg"
            ),
            preferredDensity: .standard,
            layerNotes: ["CaptureArtifactContent.photo", "ArtifactKind.photo", "photo digest can carry OCR/caption/labels but card rendering stays media-only"]
        ),
        CardDebugContentFixture(
            contentKind: .video,
            item: CaptureCardItem(
                id: "debug-kind-video",
                payload: .video(CaptureVideoCardPayload(
                    durationSeconds: 18,
                    mediaDimensions: ArtifactMediaDimensions(width: 1920, height: 1080)
                )),
                origin: .manual,
                title: "Street clip",
                detail: "Video card shows only media, centered play control, and duration.",
                metadata: "0:18"
            ),
            preferredDensity: .standard,
            layerNotes: ["CaptureArtifactContent.video", "ArtifactKind.video", "video digest can carry duration/first-frame notes"]
        ),
        CardDebugContentFixture(
            contentKind: .livePhoto,
            item: CaptureCardItem(
                id: "debug-kind-live-photo",
                payload: .livePhoto(CaptureLivePhotoCardPayload(
                    pairedVideoByteCount: 128_000,
                    mediaDimensions: ArtifactMediaDimensions(width: 3024, height: 4032)
                )),
                origin: .manual,
                title: "Live moment",
                detail: "Live Photo card shows the still frame with a non-text Live glyph.",
                metadata: "Live Photo"
            ),
            preferredDensity: .standard,
            layerNotes: ["CaptureArtifactContent.livePhoto", "ArtifactKind.livePhoto", "digest keeps still + paired video notes"]
        ),
        CardDebugContentFixture(
            contentKind: .audio,
            item: CaptureCardItem(
                id: "debug-kind-audio",
                payload: .audio(CaptureAudioCardPayload(durationSeconds: 74)),
                origin: .manual,
                title: "Voice memo",
                detail: "Transcript snippet stays in textContent and digest, not metadata.",
                metadata: "1:14"
            ),
            preferredDensity: .simple,
            layerNotes: ["CaptureArtifactContent.audio", "ArtifactKind.audio", "audio digest carries transcript/language/confidence"]
        ),
        CardDebugContentFixture(
            contentKind: .music,
            item: CaptureCardItem(
                id: "debug-kind-music",
                payload: .music(CaptureMusicCardPayload(durationSeconds: 244, playbackState: .playing)),
                origin: .context,
                title: "Midnight City",
                detail: "M83 · Hurry Up, We're Dreaming",
                metadata: "Now Playing"
            ),
            preferredDensity: .simple,
            layerNotes: ["CaptureArtifactContent.music", "ArtifactKind.music", "music fact fields stay structured"]
        ),
        CardDebugContentFixture(
            contentKind: .place,
            item: CaptureCardItem(
                id: "debug-kind-place",
                payload: .place(CapturePlaceCardPayload(latitude: 31.218, longitude: 121.446)),
                origin: .context,
                title: "Shanghai Library",
                detail: "1555 Huaihai Middle Road",
                metadata: "31.2180, 121.4460"
            ),
            preferredDensity: .standard,
            layerNotes: ["CaptureArtifactContent.location", "ArtifactKind.location", "location digest keeps structured place facts"]
        ),
        CardDebugContentFixture(
            contentKind: .weather,
            item: CaptureCardItem(
                id: "debug-kind-weather",
                payload: .weather(CaptureWeatherCardPayload(style: .cloudy, conditionCode: "mostlyCloudy", symbolName: "cloud.sun.fill", isDaylight: true)),
                origin: .context,
                title: "23°C",
                detail: "Mostly cloudy",
                metadata: "Humidity 61% · Wind 12 km/h · UV 3"
            ),
            preferredDensity: .simple,
            layerNotes: ["CaptureArtifactContent.weather", "ArtifactKind.weather", "weather summary stays structured"]
        ),
        CardDebugContentFixture(
            contentKind: .link,
            item: CaptureCardItem(
                id: "debug-kind-link",
                payload: .link(CaptureLinkCardPayload()),
                origin: .manual,
                title: "SwiftUI Layout",
                detail: "developer.apple.com/documentation/swiftui/layout",
                metadata: "developer.apple.com"
            ),
            preferredDensity: .standard,
            layerNotes: ["CaptureArtifactContent.link", "ArtifactKind.link", "URL/host remain artifact metadata facts"]
        ),
        CardDebugContentFixture(
            contentKind: .todo,
            item: CaptureCardItem(
                id: "debug-kind-todo",
                payload: .todo(CaptureTodoCardPayload()),
                origin: .manual,
                title: "Follow up",
                detail: "Send the design notes after the review.",
                metadata: "todo"
            ),
            preferredDensity: .simple,
            layerNotes: ["CaptureArtifactContent.todo", "ArtifactKind.todo", "task text remains content fact"]
        ),
        CardDebugContentFixture(
            contentKind: .person,
            item: CaptureCardItem(
                id: "debug-kind-person",
                payload: .person(CapturePersonContextCardPayload(name: "Alex Chen")),
                origin: .manual,
                title: "Alex Chen",
                detail: "Design partner from the morning critique.",
                metadata: "personContext"
            ),
            preferredDensity: .standard,
            layerNotes: ["CaptureArtifactContent.personContext", "ArtifactKind.document", "documentType=personContext"]
        ),
        CardDebugContentFixture(
            contentKind: .affect,
            item: CaptureCardItem(
                id: "debug-kind-affect",
                payload: .affect(CaptureAffectCardPayload(valence: 0.42, sourceDescription: "manual mood")),
                origin: .manual,
                title: "Steady",
                detail: "Mood from user-selected affect.",
                metadata: "affect"
            ),
            preferredDensity: .simple,
            layerNotes: ["AffectSnapshot", "not an Artifact", "debug/detail presentation node only"]
        ),
        CardDebugContentFixture(
            contentKind: .journalingSuggestion,
            item: CaptureCardItem(
                id: "debug-kind-journaling",
                payload: .journalingSuggestion(CaptureJournalingSuggestionCardPayload(artifactCount: 5, affectCount: 1, photoCount: 2, videoCount: 1, livePhotoCount: 1, locationCount: 1)),
                origin: .imported,
                title: "Journaling import",
                detail: "5 items · 1 mood",
                metadata: "Journaling"
            ),
            preferredDensity: .standard,
            layerNotes: ["journalingSuggestion(importSessionID)", "can group multiple artifacts"]
        ),
        CardDebugContentFixture(
            contentKind: .bundle,
            item: CaptureCardItem(
                id: "debug-kind-bundle",
                payload: .journalingSuggestion(
                    CaptureJournalingSuggestionCardPayload(
                        artifactCount: 3,
                        affectCount: 0,
                        photoCount: 2,
                        videoCount: 0,
                        livePhotoCount: 0,
                        locationCount: 1
                    )
                ),
                origin: .manual,
                title: "Stack",
                detail: "Grouped artifacts use one adaptive bundle card.",
                metadata: "3"
            ),
            preferredDensity: .standard,
            layerNotes: ["MemoryCardContentRef.artifactGroup", "layout stores groupID/order/zIndex only"]
        ),
        CardDebugContentFixture(
            contentKind: .status,
            item: CaptureCardItem(
                id: "debug-kind-status",
                payload: .status(CaptureStatusCardPayload()),
                origin: nil,
                title: "System note",
                detail: "Fallback/debug-only status content.",
                metadata: "debug"
            ),
            preferredDensity: .simple,
            layerNotes: ["debug/fallback only", "not a primary content fact"]
        ),
    ]

    static var typeCatalogEntries: [CardDebugTypeCatalogEntry] {
        contentFixtures.map { fixture in
            let density = MemoryCardPresentationPolicy.normalizedDensity(
                fixture.preferredDensity,
                for: fixture.contentKind
            )
            return CardDebugTypeCatalogEntry(
                contentType: contentType(for: fixture.contentKind),
                fixture: fixture,
                draftLayer: draftLayer(for: fixture.contentKind),
                artifactLayer: artifactLayer(for: fixture.contentKind),
                digestLayer: digestLayer(for: fixture.contentKind),
                arrangementLayer: "MemoryCardNode(contentRef, contentDensity=\(density.rawValue), layout=order/zIndex/rotation/nudge/stickers)"
            )
        }
    }

    static var contentDensityFixtures: [CardDebugContentDensityFixture] {
        contentFixtures.flatMap { fixture in
            MemoryCardPresentationPolicy.supportedDensities(for: fixture.contentKind).map { density in
                CardDebugContentDensityFixture(fixture: fixture, density: density)
            }
        }
    }

    static func fixture(for contentKind: MemoryCardContentKind) -> CardDebugContentFixture {
        contentFixtures.first { $0.contentKind == contentKind } ?? contentFixtures[0]
    }

    static func arrangementPlaygroundSnapshot() -> MemoryDetailSnapshot {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recordID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let photoID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let audioID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let linkID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let weatherID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let placeID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let musicID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let artifacts = [
            Artifact(
                id: photoID,
                recordID: recordID,
                kind: .photo,
                title: "Kitchen light",
                summary: "Photo media artifact",
                mediaRef: ArtifactMediaRef(filename: "photo.jpg", mimeType: "image/jpeg"),
                createdAt: now,
                updatedAt: now
            ),
            Artifact(
                id: audioID,
                recordID: recordID,
                kind: .audio,
                title: "Voice memo",
                summary: "Audio summary",
                textContent: "Transcript snippet for the audio card.",
                mediaRef: ArtifactMediaRef(filename: "voice.m4a", mimeType: "audio/mp4"),
                createdAt: now,
                updatedAt: now
            ),
            Artifact(
                id: linkID,
                recordID: recordID,
                kind: .link,
                title: "SwiftUI Layout",
                summary: "developer.apple.com/documentation/swiftui/layout",
                metadata: ["url": "https://developer.apple.com/documentation/swiftui/layout"],
                createdAt: now,
                updatedAt: now
            ),
            Artifact(
                id: weatherID,
                recordID: recordID,
                kind: .weather,
                title: "23°C",
                summary: "Mostly cloudy",
                metadata: ["condition": "Mostly cloudy", "temperatureCelsius": "23", "humidity": "0.61", "windSpeedKmh": "12", "uvIndex": "3", "conditionCode": "mostlyCloudy", "symbolName": "cloud.sun.fill"],
                createdAt: now,
                updatedAt: now
            ),
            Artifact(
                id: placeID,
                recordID: recordID,
                kind: .location,
                title: "Shanghai Library",
                summary: "1555 Huaihai Middle Road",
                metadata: ["latitude": "31.218", "longitude": "121.446"],
                createdAt: now,
                updatedAt: now
            ),
            Artifact(
                id: musicID,
                recordID: recordID,
                kind: .music,
                title: "Midnight City",
                summary: "M83 · Hurry Up, We're Dreaming",
                metadata: ["trackName": "Midnight City", "artistName": "M83", "albumName": "Hurry Up, We're Dreaming", "durationSeconds": "244"],
                createdAt: now,
                updatedAt: now
            ),
        ]
        let record = RecordShell(
            id: recordID,
            createdAt: now,
            updatedAt: now,
            captureSource: .composer,
            rawText: "Debug arrangement playground: the renderer should preserve order, rotation, nudge, z-index, stickers, stack, and content density.",
            artifactIDs: artifacts.map(\.id)
        )
        let arrangement = MemoryCardArrangement(
            recordID: recordID,
            nodes: [
                MemoryCardNode(contentRef: .recordBody, contentDensity: .detailed, layout: MemoryCardLayoutToken(order: 0, rotationDegrees: -1.5, zIndex: 0)),
                MemoryCardNode(contentRef: .artifact(photoID), contentDensity: .standard, layout: MemoryCardLayoutToken(order: 1, rotationDegrees: 2, zIndex: 1)),
                MemoryCardNode(contentRef: .artifact(audioID), contentDensity: .simple, layout: MemoryCardLayoutToken(order: 2, rotationDegrees: -2, zIndex: 2)),
                MemoryCardNode(contentRef: .artifact(linkID), contentDensity: .standard, layout: MemoryCardLayoutToken(order: 3, rotationDegrees: 1, zIndex: 3)),
                MemoryCardNode(contentRef: .artifact(weatherID), contentDensity: .simple, layout: MemoryCardLayoutToken(order: 4, rotationDegrees: -3, zIndex: 4)),
                MemoryCardNode(contentRef: .artifact(placeID), contentDensity: .standard, layout: MemoryCardLayoutToken(order: 5, rotationDegrees: 1.5, zIndex: 5)),
                MemoryCardNode(contentRef: .artifact(musicID), contentDensity: .simple, layout: MemoryCardLayoutToken(order: 6, rotationDegrees: -1, zIndex: 6)),
                MemoryCardNode(contentRef: .artifactGroup([photoID, linkID, weatherID], kind: .mixedContext), contentDensity: .standard, layout: MemoryCardLayoutToken(order: 7, rotationDegrees: 2.5, zIndex: 7)),
            ],
            createdAt: now,
            updatedAt: now
        )
        return MemoryDetailSnapshot(
            record: record,
            artifacts: artifacts,
            artifactSemanticDigests: [],
            cardArrangement: arrangement,
            analysis: nil,
            pipelineStatus: nil,
            entities: [],
            edges: [],
            arcs: [],
            reflections: []
        )
    }

    private static func contentType(for contentKind: MemoryCardContentKind) -> String {
        switch contentKind {
        case .recordBody: return "recordBody / text"
        case .photo: return "photo"
        case .video: return "video"
        case .livePhoto: return "livePhoto"
        case .audio: return "audio"
        case .place: return "location"
        case .weather: return "weather"
        case .music: return "music"
        case .link: return "link"
        case .todo: return "todo"
        case .prompt: return "promptAnswer"
        case .person: return "personContext"
        case .affect: return "affect"
        case .journalingSuggestion: return "journaling suggestion"
        case .bundle: return "stack / bundle"
        case .status: return "status/debug"
        }
    }

    private static func draftLayer(for contentKind: MemoryCardContentKind) -> String {
        switch contentKind {
        case .recordBody, .prompt:
            return "MemoryCaptureDraft.bodyText or CaptureArtifactContent.text/promptAnswer"
        case .affect:
            return "Affect draft / AffectSnapshot"
        case .journalingSuggestion, .bundle:
            return "Journaling import session or grouped artifact draft nodes"
        case .status:
            return "Debug status fixture"
        default:
            return "CaptureArtifactDraft(content)"
        }
    }

    private static func artifactLayer(for contentKind: MemoryCardContentKind) -> String {
        switch contentKind {
        case .recordBody:
            return "RecordShell.rawText or ArtifactKind.text/document"
        case .person:
            return "ArtifactKind.document + documentType=personContext"
        case .affect:
            return "AffectSnapshot, not Artifact"
        case .journalingSuggestion, .bundle:
            return "Artifact[] grouped by importSessionID or stack node"
        case .status:
            return "Debug-only status payload"
        default:
            return "Artifact(kind/title/summary/textContent/mediaRef/technical metadata)"
        }
    }

    private static func digestLayer(for contentKind: MemoryCardContentKind) -> String {
        switch contentKind {
        case .photo, .video, .livePhoto, .audio:
            return "ArtifactSemanticDigest stores media meaning outside Artifact.metadata"
        case .affect, .status:
            return "No artifact semantic digest"
        default:
            return "Structured digest when content type provides semantic evidence"
        }
    }
}
