import Foundation

struct CardDebugRecipeFixture: Identifiable, Hashable {
    var id: String { recipe.rawValue }
    let recipe: MemoryCardVisualRecipe
    let item: CaptureCardItem
    let preferredDensity: MemoryCardContentDensity
    let preferredVariant: MemoryCardVisualVariant?
    let layerNotes: [String]
}

struct CardDebugTypeCatalogEntry: Identifiable, Hashable {
    var id: String { contentType }
    let contentType: String
    let fixture: CardDebugRecipeFixture
    let draftLayer: String
    let artifactLayer: String
    let digestLayer: String
    let arrangementLayer: String
}

struct CardDebugRecipeDensityFixture: Identifiable, Hashable {
    var id: String {
        "\(fixture.recipe.rawValue)-\(density.rawValue)-\(resolvedVariant.rawValue)"
    }
    let fixture: CardDebugRecipeFixture
    let density: MemoryCardContentDensity
    let variant: MemoryCardVisualVariant?

    var metrics: MemoryCardObjectMetrics {
        MemoryCardObjectMetrics.resolve(recipe: fixture.recipe, density: density)
    }

    var resolvedVariant: MemoryCardVisualVariant {
        MemoryCardRecipeLayoutPolicy.resolvedVariant(variant, for: fixture.recipe, density: density)
    }
}

enum CardDebugCatalog {
    static let recipeFixtures: [CardDebugRecipeFixture] = [
        CardDebugRecipeFixture(
            recipe: .notebook,
            item: CaptureCardItem(
                id: "debug-recipe-notebook",
                payload: .prompt(CapturePromptCardPayload(prompt: "What should be remembered?", answer: "A quiet morning note with the core record body.")),
                origin: .manual,
                title: "Record body",
                detail: "A quiet morning note with the core record body.",
                metadata: "recordBody"
            ),
            preferredDensity: .expanded,
            preferredVariant: nil,
            layerNotes: ["contentRef=.recordBody", "ArtifactKind.text is folded into RecordShell.rawText", "visualRecipe=.notebook"]
        ),
        CardDebugRecipeFixture(
            recipe: .polaroid,
            item: CaptureCardItem(
                id: "debug-recipe-polaroid",
                payload: .photo(CapturePhotoCardPayload(photoCount: 1)),
                origin: .manual,
                title: "Kitchen light",
                detail: "Photo evidence with a white border and timestamp area.",
                metadata: "photo.jpg"
            ),
            preferredDensity: .regular,
            preferredVariant: nil,
            layerNotes: ["CaptureArtifactContent.photo", "ArtifactKind.photo", "photo digest can carry OCR/caption/labels", "visualRecipe=.polaroid"]
        ),
        CardDebugRecipeFixture(
            recipe: .filmFrame,
            item: CaptureCardItem(
                id: "debug-recipe-film-frame",
                payload: .video(CaptureVideoCardPayload(durationSeconds: 18)),
                origin: .manual,
                title: "Street clip",
                detail: "Video evidence with first-frame summary.",
                metadata: "0:18"
            ),
            preferredDensity: .regular,
            preferredVariant: nil,
            layerNotes: ["CaptureArtifactContent.video", "ArtifactKind.video", "video digest can carry duration/first-frame notes", "visualRecipe=.filmFrame"]
        ),
        CardDebugRecipeFixture(
            recipe: .livePhotoPrint,
            item: CaptureCardItem(
                id: "debug-recipe-live-photo-print",
                payload: .livePhoto(CaptureLivePhotoCardPayload(pairedVideoByteCount: 128_000)),
                origin: .manual,
                title: "Live moment",
                detail: "Still image plus paired motion clip.",
                metadata: "Live Photo"
            ),
            preferredDensity: .regular,
            preferredVariant: nil,
            layerNotes: ["CaptureArtifactContent.livePhoto", "ArtifactKind.livePhoto", "digest keeps still + paired video notes", "visualRecipe=.livePhotoPrint"]
        ),
        CardDebugRecipeFixture(
            recipe: .cassette,
            item: CaptureCardItem(
                id: "debug-recipe-cassette",
                payload: .audio(CaptureAudioCardPayload(durationSeconds: 74)),
                origin: .manual,
                title: "Voice memo",
                detail: "Transcript snippet stays in textContent and digest, not metadata.",
                metadata: "1:14"
            ),
            preferredDensity: .compact,
            preferredVariant: nil,
            layerNotes: ["CaptureArtifactContent.audio", "ArtifactKind.audio", "audio digest carries transcript/language/confidence", "visualRecipe=.cassette"]
        ),
        CardDebugRecipeFixture(
            recipe: .vinyl,
            item: CaptureCardItem(
                id: "debug-recipe-vinyl",
                payload: .music(CaptureMusicCardPayload(durationSeconds: 244, playbackState: .playing)),
                origin: .context,
                title: "Midnight City",
                detail: "M83 · Hurry Up, We're Dreaming",
                metadata: "Now Playing"
            ),
            preferredDensity: .compact,
            preferredVariant: nil,
            layerNotes: ["CaptureArtifactContent.music", "ArtifactKind.music", "music fact fields stay structured", "visualRecipe=.vinyl"]
        ),
        CardDebugRecipeFixture(
            recipe: .mapTicket,
            item: CaptureCardItem(
                id: "debug-recipe-map-ticket",
                payload: .place(CapturePlaceCardPayload(latitude: 31.218, longitude: 121.446)),
                origin: .context,
                title: "Shanghai Library",
                detail: "1555 Huaihai Middle Road",
                metadata: "31.2180, 121.4460"
            ),
            preferredDensity: .regular,
            preferredVariant: nil,
            layerNotes: ["CaptureArtifactContent.location", "ArtifactKind.location", "location digest keeps structured place facts", "visualRecipe=.mapTicket"]
        ),
        CardDebugRecipeFixture(
            recipe: .weatherStamp,
            item: CaptureCardItem(
                id: "debug-recipe-weather-stamp",
                payload: .weather(CaptureWeatherCardPayload(style: .cloudy, conditionCode: "mostlyCloudy", symbolName: "cloud.sun.fill", isDaylight: true)),
                origin: .context,
                title: "23°C",
                detail: "Mostly cloudy",
                metadata: "Humidity 61% · Wind 12 km/h · UV 3"
            ),
            preferredDensity: .compact,
            preferredVariant: nil,
            layerNotes: ["CaptureArtifactContent.weather", "ArtifactKind.weather", "weather summary stays structured", "visualRecipe=.weatherStamp"]
        ),
        CardDebugRecipeFixture(
            recipe: .linkNote,
            item: CaptureCardItem(
                id: "debug-recipe-link-note",
                payload: .link(CaptureLinkCardPayload()),
                origin: .manual,
                title: "SwiftUI Layout",
                detail: "developer.apple.com/documentation/swiftui/layout",
                metadata: "developer.apple.com"
            ),
            preferredDensity: .regular,
            preferredVariant: nil,
            layerNotes: ["CaptureArtifactContent.link", "ArtifactKind.link", "URL/host remain artifact metadata facts", "visualRecipe=.linkNote"]
        ),
        CardDebugRecipeFixture(
            recipe: .taskNote,
            item: CaptureCardItem(
                id: "debug-recipe-task-note",
                payload: .todo(CaptureTodoCardPayload()),
                origin: .manual,
                title: "Follow up",
                detail: "Send the design notes after the review.",
                metadata: "todo"
            ),
            preferredDensity: .compact,
            preferredVariant: nil,
            layerNotes: ["CaptureArtifactContent.todo", "ArtifactKind.todo", "task text remains content fact", "visualRecipe=.taskNote"]
        ),
        CardDebugRecipeFixture(
            recipe: .personCard,
            item: CaptureCardItem(
                id: "debug-recipe-person-card",
                payload: .person(CapturePersonContextCardPayload(name: "Alex Chen")),
                origin: .manual,
                title: "Alex Chen",
                detail: "Design partner from the morning critique.",
                metadata: "personContext"
            ),
            preferredDensity: .regular,
            preferredVariant: nil,
            layerNotes: ["CaptureArtifactContent.personContext", "ArtifactKind.document", "documentType=personContext", "visualRecipe=.personCard"]
        ),
        CardDebugRecipeFixture(
            recipe: .affectCard,
            item: CaptureCardItem(
                id: "debug-recipe-affect-card",
                payload: .affect(CaptureAffectCardPayload(valence: 0.42, sourceDescription: "manual mood")),
                origin: .manual,
                title: "Steady",
                detail: "Mood swatch from user-selected affect.",
                metadata: "affect"
            ),
            preferredDensity: .compact,
            preferredVariant: nil,
            layerNotes: ["AffectSnapshot", "not an Artifact", "debug/detail presentation node only", "visualRecipe=.affectCard"]
        ),
        CardDebugRecipeFixture(
            recipe: .bundlePacket,
            item: CaptureCardItem(
                id: "debug-recipe-bundle-packet",
                payload: .journalingSuggestion(CaptureJournalingSuggestionCardPayload(artifactCount: 5, affectCount: 1, photoCount: 2, videoCount: 1, livePhotoCount: 1, locationCount: 1)),
                origin: .imported,
                title: "Journaling import",
                detail: "5 items · 1 mood",
                metadata: "Journaling"
            ),
            preferredDensity: .regular,
            preferredVariant: nil,
            layerNotes: ["journalingSuggestion(importSessionID)", "can group multiple artifacts", "visualRecipe=.bundlePacket"]
        ),
        CardDebugRecipeFixture(
            recipe: .statusNote,
            item: CaptureCardItem(
                id: "debug-recipe-status-note",
                payload: .status(CaptureStatusCardPayload()),
                origin: nil,
                title: "System note",
                detail: "Fallback/debug-only status content.",
                metadata: "debug"
            ),
            preferredDensity: .compact,
            preferredVariant: nil,
            layerNotes: ["debug/fallback only", "not a primary content fact", "visualRecipe=.statusNote"]
        ),
    ]

    static var typeCatalogEntries: [CardDebugTypeCatalogEntry] {
        recipeFixtures.map { fixture in
            let density = MemoryCardRecipeLayoutPolicy.normalizedDensity(fixture.preferredDensity, for: fixture.recipe)
            return CardDebugTypeCatalogEntry(
                contentType: contentType(for: fixture.recipe),
                fixture: fixture,
                draftLayer: draftLayer(for: fixture.recipe),
                artifactLayer: artifactLayer(for: fixture.recipe),
                digestLayer: digestLayer(for: fixture.recipe),
                arrangementLayer: "MemoryCardNode(contentRef, visualRecipe=\(fixture.recipe.rawValue), variant=\(MemoryCardRecipeLayoutPolicy.resolvedVariant(fixture.preferredVariant, for: fixture.recipe, density: density).rawValue), density=\(density.rawValue), layout=order/zIndex/rotation/nudge/stickers)"
            )
        }
    }

    static var recipeDensityFixtures: [CardDebugRecipeDensityFixture] {
        recipeFixtures.flatMap { fixture in
            MemoryCardRecipeLayoutPolicy.supportedDensities(for: fixture.recipe).map { density in
                let variants = MemoryCardRecipeLayoutPolicy.supportedVariants(for: fixture.recipe, density: density)
                return variants.map { variant in
                    CardDebugRecipeDensityFixture(
                        fixture: fixture,
                        density: density,
                        variant: variant == .automatic ? nil : variant
                    )
                }
            }
            .flatMap { $0 }
        }
    }

    static func fixture(for recipe: MemoryCardVisualRecipe) -> CardDebugRecipeFixture {
        recipeFixtures.first { $0.recipe == recipe } ?? recipeFixtures[0]
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
                summary: "Photo evidence",
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
                textContent: "Transcript snippet for the cassette card.",
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
            rawText: "Debug arrangement playground: the renderer should preserve recipe, order, rotation, nudge, z-index, stickers, and stack.",
            artifactIDs: artifacts.map(\.id)
        )
        let arrangement = MemoryCardArrangement(
            recordID: recordID,
            nodes: [
                MemoryCardNode(contentRef: .recordBody, visualRecipe: .notebook, layout: MemoryCardLayoutToken(order: 0, rotationDegrees: -1.5, zIndex: 0)),
                MemoryCardNode(contentRef: .artifact(photoID), visualRecipe: .polaroid, layout: MemoryCardLayoutToken(order: 1, rotationDegrees: 2, zIndex: 1)),
                MemoryCardNode(contentRef: .artifact(audioID), visualRecipe: .cassette, layout: MemoryCardLayoutToken(order: 2, rotationDegrees: -2, zIndex: 2)),
                MemoryCardNode(contentRef: .artifact(linkID), visualRecipe: .linkNote, layout: MemoryCardLayoutToken(order: 3, rotationDegrees: 1, zIndex: 3)),
                MemoryCardNode(contentRef: .artifact(weatherID), visualRecipe: .weatherStamp, layout: MemoryCardLayoutToken(order: 4, rotationDegrees: -3, zIndex: 4)),
                MemoryCardNode(contentRef: .artifact(placeID), visualRecipe: .mapTicket, layout: MemoryCardLayoutToken(order: 5, rotationDegrees: 1.5, zIndex: 5)),
                MemoryCardNode(contentRef: .artifact(musicID), visualRecipe: .vinyl, layout: MemoryCardLayoutToken(order: 6, rotationDegrees: -1, zIndex: 6)),
                MemoryCardNode(contentRef: .artifactGroup([photoID, linkID, weatherID], kind: .mixedContext), visualRecipe: .bundlePacket, layout: MemoryCardLayoutToken(order: 7, rotationDegrees: 2.5, zIndex: 7)),
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

    private static func contentType(for recipe: MemoryCardVisualRecipe) -> String {
        switch recipe {
        case .notebook: return "recordBody / text / promptAnswer"
        case .polaroid: return "photo"
        case .filmFrame: return "video"
        case .livePhotoPrint: return "livePhoto"
        case .cassette: return "audio"
        case .vinyl: return "music"
        case .mapTicket: return "location"
        case .weatherStamp: return "weather"
        case .linkNote: return "link"
        case .taskNote: return "todo"
        case .personCard: return "personContext"
        case .affectCard: return "affect"
        case .bundlePacket: return "journaling suggestion / stack"
        case .statusNote: return "status/debug"
        }
    }

    private static func draftLayer(for recipe: MemoryCardVisualRecipe) -> String {
        switch recipe {
        case .notebook: return "MemoryCaptureDraft.bodyText or CaptureArtifactContent.text/promptAnswer"
        case .affectCard: return "Affect draft / AffectSnapshot"
        case .bundlePacket: return "Journaling import session or grouped artifact draft nodes"
        case .statusNote: return "Debug status fixture"
        default: return "CaptureArtifactDraft(content)"
        }
    }

    private static func artifactLayer(for recipe: MemoryCardVisualRecipe) -> String {
        switch recipe {
        case .notebook: return "RecordShell.rawText or ArtifactKind.text/document"
        case .personCard: return "ArtifactKind.document + documentType=personContext"
        case .affectCard: return "AffectSnapshot, not Artifact"
        case .bundlePacket: return "Artifact[] grouped by importSessionID or stack node"
        case .statusNote: return "Debug-only status payload"
        default: return "Artifact(kind/title/summary/textContent/mediaRef/technical metadata)"
        }
    }

    private static func digestLayer(for recipe: MemoryCardVisualRecipe) -> String {
        switch recipe {
        case .polaroid, .filmFrame, .livePhotoPrint, .cassette:
            return "ArtifactSemanticDigest stores media meaning outside Artifact.metadata"
        case .affectCard, .statusNote:
            return "No artifact semantic digest"
        default:
            return "Structured digest when content type provides semantic evidence"
        }
    }
}
