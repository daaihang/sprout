import XCTest
import UIKit
@testable import mory

final class CaptureCardModelsTests: XCTestCase {
    func testContextAttachmentKeepsConcretePlaceKind() {
        let candidate = ContextCandidate(
            draft: .location(
                title: "Cafe",
                summary: "Near the station",
                latitude: 31.2,
                longitude: 121.4,
                origin: .context
            ),
            capturedAt: Date(timeIntervalSince1970: 1_800_000_000),
            isSelected: true
        )

        let attachment = CaptureComposerAttachmentItem.context(candidate)
        let card = CaptureCardItem(attachment: attachment)

        XCTAssertEqual(card.kind, .place)
        XCTAssertEqual(card.origin, .context)
        XCTAssertFalse(card.isSelected)
        XCTAssertTrue(card.isRemovable)
        XCTAssertEqual(card.state, .normal)
    }

    func testStatusAttachmentMapsToLoadingStatusCard() {
        let attachment = CaptureComposerAttachmentItem.processing(
            id: "context",
            detail: "Collecting context"
        )

        let card = CaptureCardItem(attachment: attachment)

        XCTAssertEqual(card.kind, .status)
        XCTAssertNil(card.origin)
        XCTAssertEqual(card.state, .loading)
        XCTAssertEqual(card.detail, "Collecting context")
    }

    func testPayloadDerivesKindAndScopesTypedFields() {
        let card = CaptureCardItem(
            payload: .weather(CaptureWeatherCardPayload(
                latitude: 31.2,
                longitude: 121.4,
                style: .rain,
                conditionCode: "rain",
                symbolName: "cloud.rain.fill",
                isDaylight: true
            )),
            title: "18°",
            detail: "Rain"
        )

        XCTAssertEqual(card.kind, .weather)
        guard case let .weather(payload) = card.payload else {
            return XCTFail("Expected weather payload.")
        }
        XCTAssertEqual(payload.latitude, 31.2)
        XCTAssertEqual(payload.longitude, 121.4)
        XCTAssertEqual(payload.style, .rain)
        XCTAssertEqual(payload.conditionCode, "rain")
        XCTAssertEqual(payload.symbolName, "cloud.rain.fill")
        XCTAssertEqual(payload.isDaylight, true)
    }

    func testPayloadMutationsStayInsideTypedPayload() {
        let artwork = makeImageData(color: .systemIndigo)
        var card = CaptureCardItem(
            payload: .music(CaptureMusicCardPayload(playbackState: .paused)),
            title: "Track",
            detail: "Artist"
        )

        guard case .music(var musicPayload) = card.payload else {
            return XCTFail("Expected music payload.")
        }
        musicPayload.artworkData = artwork
        musicPayload.artworkURL = "https://example.com/artwork.jpg"
        musicPayload.playbackState = .playing
        card.payload = .music(musicPayload)

        guard case let .music(payload) = card.payload else {
            return XCTFail("Expected music payload.")
        }
        XCTAssertEqual(card.kind, .music)
        XCTAssertEqual(payload.artworkData, artwork)
        XCTAssertEqual(payload.artworkURL, "https://example.com/artwork.jpg")
        XCTAssertEqual(payload.playbackState, .playing)
        XCTAssertTrue(payload.artworkData != nil || payload.artworkURL?.trimmedOrNil != nil)
    }

    func testSavedPhotoArtifactMapsToProductionCaptureCard() {
        let thumbnail = makeImageData(color: .systemPink)
        let artifact = Artifact(
            recordID: UUID(),
            kind: .photo,
            title: "Morning photo",
            summary: "Kitchen light",
            mediaRef: ArtifactMediaRef(filename: "photo.jpg", mimeType: "image/jpeg"),
            metadata: ["captureOrigin": CaptureArtifactOrigin.manual.rawValue],
            previewPayload: thumbnail,
            createdAt: .now,
            updatedAt: .now
        )

        let card = CaptureCardItem(artifact: artifact)

        XCTAssertEqual(card.kind, .photo)
        XCTAssertEqual(card.origin, .manual)
        XCTAssertEqual(card.title, "Morning photo")
        XCTAssertEqual(card.detail, "Kitchen light")
        guard case let .photo(payload) = card.payload else {
            return XCTFail("Expected photo payload.")
        }
        XCTAssertEqual(payload.thumbnailData, thumbnail)
        XCTAssertFalse(card.isRemovable)
    }

    func testSavedWeatherArtifactMapsStableConditionFields() {
        let artifact = Artifact(
            recordID: UUID(),
            kind: .weather,
            title: "Mostly clear 24°C",
            summary: "Mostly clear · 24°C",
            metadata: [
                "captureOrigin": CaptureArtifactOrigin.context.rawValue,
                "condition": "大部晴朗无云",
                "temperatureCelsius": "24.2",
                "humidity": "0.62",
                "windSpeedKmh": "9.5",
                "uvIndex": "2",
                "conditionCode": "mostlyClear",
                "symbolName": "sun.max.fill",
                "isDaylight": "true"
            ],
            createdAt: .now,
            updatedAt: .now
        )

        let card = CaptureCardItem(artifact: artifact)

        XCTAssertEqual(card.kind, .weather)
        XCTAssertEqual(card.origin, .context)
        XCTAssertEqual(card.title, captureWeatherTemperatureTitle(24.2))
        XCTAssertEqual(card.detail, "大部晴朗无云")
        guard case let .weather(payload) = card.payload else {
            return XCTFail("Expected weather payload.")
        }
        XCTAssertEqual(payload.conditionCode, "mostlyClear")
        XCTAssertEqual(payload.symbolName, "sun.max.fill")
        XCTAssertEqual(payload.style, .sunny)
        XCTAssertNotNil(card.metadata)
    }

    func testSavedMusicArtifactDoesNotAnimateAsLivePlayback() {
        let artifact = Artifact(
            recordID: UUID(),
            kind: .music,
            title: "Track - Artist",
            summary: "Track · Artist · Album",
            metadata: [
                "captureOrigin": CaptureArtifactOrigin.context.rawValue,
                "trackName": "Track",
                "artistName": "Artist",
                "albumName": "Album",
                "durationSeconds": "180",
                "artworkBackgroundColor": "#101820",
                "artworkPrimaryTextColor": "#FFFFFF"
            ],
            createdAt: .now,
            updatedAt: .now
        )

        let card = CaptureCardItem(artifact: artifact)

        XCTAssertEqual(card.kind, .music)
        XCTAssertEqual(card.origin, .context)
        XCTAssertEqual(card.title, "Track")
        XCTAssertEqual(card.detail, "Artist · Album")
        guard case let .music(payload) = card.payload else {
            return XCTFail("Expected music payload.")
        }
        XCTAssertEqual(payload.durationSeconds, 180)
        XCTAssertEqual(payload.playbackState, .stopped)
        XCTAssertEqual(payload.artworkPalette?.backgroundColorHex, "#101820")
    }

    func testProcessingAttachmentsCanKeepConcreteCardKinds() {
        let photo = CaptureCardItem(attachment: .processing(
            id: "photo",
            kind: .photo,
            detail: "Analyzing photo"
        ))
        let audio = CaptureCardItem(attachment: .processing(
            id: "voice",
            kind: .audio,
            detail: "Refining transcript"
        ))

        XCTAssertEqual(photo.kind, .photo)
        XCTAssertEqual(photo.state, .loading)
        XCTAssertEqual(photo.title, CaptureCardKind.photo.label)
        XCTAssertEqual(audio.kind, .audio)
        XCTAssertEqual(audio.state, .loading)
        XCTAssertEqual(audio.title, CaptureCardKind.audio.label)
    }

    func testOnlyNormalCardsDisplaySelection() {
        for state in CaptureCardState.allCases {
            let presentation = CaptureCardPresentation.debug(
                CaptureCardItem(
                    payload: .weather(CaptureWeatherCardPayload()),
                    state: state,
                    detail: "State test",
                    isSelected: true
                )
            )
            XCTAssertEqual(presentation.displaysSelection, state == .normal)
        }
    }

    func testTransientCardsDoNotAllowPrimaryAction() {
        let make = { (state: CaptureCardState) in
            CaptureCardPresentation(
                item: CaptureCardItem(payload: .photo(CapturePhotoCardPayload()), state: state, detail: "Test"),
                role: .composerEditing,
                provenanceDisplayMode: .production
            )
        }
        XCTAssertTrue(make(.normal).allowsPrimaryAction)
        XCTAssertFalse(make(.loading).allowsPrimaryAction)
        XCTAssertFalse(make(.error).allowsPrimaryAction)
        XCTAssertFalse(make(.disabled).allowsPrimaryAction)
    }

    func testErrorRemovableCardsKeepRemoveAffordanceButNotSelection() {
        let presentation = CaptureCardPresentation(
            item: CaptureCardItem(
                payload: .photo(CapturePhotoCardPayload()),
                state: .error,
                detail: "Upload failed",
                isSelected: true,
                isRemovable: true
            ),
            role: .composerEditing,
            provenanceDisplayMode: .production
        )

        XCTAssertFalse(presentation.displaysSelection)
        XCTAssertTrue(presentation.displaysRemoveControl)
    }

    func testRemovableNormalCardsPreferRemoveOverSelectedAffordance() {
        let presentation = CaptureCardPresentation.debug(
            CaptureCardItem(
                payload: .weather(CaptureWeatherCardPayload()),
                state: .normal,
                detail: "Included context",
                isSelected: true,
                isRemovable: true
            )
        )

        XCTAssertFalse(presentation.displaysSelection)
        XCTAssertTrue(presentation.displaysRemoveControl)
    }

    func testTrailingControlsOverlayWithoutContentAvoidanceModel() {
        let plain = CaptureCardPresentation(
            item: CaptureCardItem(payload: .link(CaptureLinkCardPayload()), state: .normal, detail: "Plain"),
            role: .composerEditing, provenanceDisplayMode: .production
        )
        let removable = CaptureCardPresentation(
            item: CaptureCardItem(payload: .link(CaptureLinkCardPayload()), state: .normal, detail: "Remove", isRemovable: true),
            role: .composerEditing, provenanceDisplayMode: .production
        )
        let selected = CaptureCardPresentation.debug(
            CaptureCardItem(payload: .link(CaptureLinkCardPayload()), state: .normal, detail: "Selected", isSelected: true)
        )
        let loading = CaptureCardPresentation(
            item: CaptureCardItem(payload: .link(CaptureLinkCardPayload()), state: .loading, detail: "Loading"),
            role: .composerEditing, provenanceDisplayMode: .production
        )

        XCTAssertFalse(plain.hasTrailingControl)
        XCTAssertTrue(removable.hasTrailingControl)
        XCTAssertTrue(selected.hasTrailingControl)
        XCTAssertTrue(loading.hasTrailingControl)
    }

    func testLoadingAndDisabledCardsDoNotDisplayRemoveControl() {
        let loading = CaptureCardPresentation(
            item: CaptureCardItem(payload: .photo(CapturePhotoCardPayload()), state: .loading, detail: "Processing", isRemovable: true),
            role: .composerEditing,
            provenanceDisplayMode: .production
        )
        let disabled = CaptureCardPresentation(
            item: CaptureCardItem(payload: .photo(CapturePhotoCardPayload()), state: .disabled, detail: "Unavailable", isRemovable: true),
            role: .composerEditing,
            provenanceDisplayMode: .production
        )

        XCTAssertFalse(loading.displaysRemoveControl)
        XCTAssertFalse(disabled.displaysRemoveControl)
    }

    func testComposerPresentationControlsRemoveButNotSelection() {
        let card = CaptureCardItem(
            payload: .weather(CaptureWeatherCardPayload()),
            state: .normal,
            detail: "Included context",
            isSelected: true,
            isRemovable: true
        )
        let presentation = CaptureCardPresentation(
            item: card,
            role: .composerEditing,
            provenanceDisplayMode: .production
        )

        XCTAssertTrue(presentation.allowsPrimaryAction)
        XCTAssertTrue(presentation.displaysRemoveControl)
        XCTAssertFalse(presentation.displaysSelection)
        XCTAssertTrue(presentation.hasTrailingControl)
    }

    func testComposerPresentationDoesNotRemoveLoadingOrDisabledCards() {
        let loading = CaptureCardPresentation(
            item: CaptureCardItem(payload: .photo(CapturePhotoCardPayload()), state: .loading, detail: "Processing", isRemovable: true),
            role: .composerEditing,
            provenanceDisplayMode: .production
        )
        let disabled = CaptureCardPresentation(
            item: CaptureCardItem(payload: .photo(CapturePhotoCardPayload()), state: .disabled, detail: "Unavailable", isRemovable: true),
            role: .composerEditing,
            provenanceDisplayMode: .production
        )

        XCTAssertFalse(loading.allowsPrimaryAction)
        XCTAssertFalse(loading.displaysRemoveControl)
        XCTAssertTrue(loading.hasTrailingControl)
        XCTAssertFalse(disabled.allowsPrimaryAction)
        XCTAssertFalse(disabled.displaysRemoveControl)
    }

    func testDetailViewingPresentationNeverDisplaysEditControls() {
        let card = CaptureCardItem(
            payload: .photo(CapturePhotoCardPayload()),
            state: .normal,
            detail: "Saved photo",
            isSelected: true,
            isRemovable: true
        )
        let presentation = CaptureCardPresentation(
            item: card,
            role: .detailViewing,
            provenanceDisplayMode: .production
        )

        XCTAssertTrue(presentation.allowsPrimaryAction)
        XCTAssertFalse(presentation.displaysRemoveControl)
        XCTAssertFalse(presentation.displaysSelection)
        XCTAssertFalse(presentation.hasTrailingControl)
    }

    func testDebugLabPresentationRespectsFixtureSelectionAndRemoval() {
        let selected = CaptureCardPresentation.debug(
            CaptureCardItem(payload: .todo(CaptureTodoCardPayload()), state: .normal, detail: "Selected", isSelected: true)
        )
        let removable = CaptureCardPresentation.debug(
            CaptureCardItem(payload: .todo(CaptureTodoCardPayload()), state: .normal, detail: "Remove", isRemovable: true)
        )

        XCTAssertTrue(selected.displaysSelection)
        XCTAssertFalse(selected.displaysRemoveControl)
        XCTAssertTrue(removable.displaysRemoveControl)
        XCTAssertFalse(removable.displaysSelection)
    }

    func testComposerAndDetailFactoriesChooseProductionPresentation() {
        let candidate = ContextCandidate(
            draft: .weather(
                condition: "Rain",
                temperatureCelsius: 18,
                humidity: 0.8,
                windSpeedKmh: 12,
                uvIndex: 2,
                latitude: nil,
                longitude: nil,
                conditionCode: "rain",
                symbolName: "cloud.rain.fill",
                isDaylight: true,
                origin: .context
            ),
            capturedAt: Date(timeIntervalSince1970: 1_800_000_000),
            isSelected: true
        )
        let composer = CaptureCardPresentation.composerAttachment(.context(candidate))

        XCTAssertEqual(composer.role, .composerEditing)
        XCTAssertEqual(composer.provenanceDisplayMode, .production)
        XCTAssertEqual(composer.item.kind, .weather)
        XCTAssertEqual(composer.item.origin, .context)
        XCTAssertTrue(composer.displaysRemoveControl)

        let artifact = Artifact(
            recordID: UUID(),
            kind: .weather,
            title: "Rain",
            summary: "Rain",
            metadata: ["captureOrigin": CaptureArtifactOrigin.context.rawValue],
            createdAt: .now,
            updatedAt: .now
        )
        let detail = CaptureCardPresentation.detailArtifact(artifact)

        XCTAssertEqual(detail.role, .detailViewing)
        XCTAssertEqual(detail.provenanceDisplayMode, .production)
        XCTAssertEqual(detail.item.kind, .weather)
        XCTAssertFalse(detail.displaysRemoveControl)

        let editing = CaptureCardPresentation.detailEditing(artifact)
        XCTAssertEqual(editing.role, .detailEditing)
        XCTAssertEqual(editing.provenanceDisplayMode, .production)
        XCTAssertTrue(editing.capabilities.canOpen)
        XCTAssertTrue(editing.capabilities.canReorder)
        XCTAssertFalse(editing.capabilities.canRemove)
        XCTAssertFalse(editing.displaysRemoveControl)
        XCTAssertFalse(editing.displaysSelection)
    }

    func testFixturesCoverAllConcreteArtifactKindsWithoutAutoContextKind() {
        let fixtureKinds = Set(CaptureCardLabFixtures.allTypes.map(\.kind))

        XCTAssertTrue(fixtureKinds.isSuperset(of: [.photo, .audio, .place, .weather, .music, .link, .todo]))
        XCTAssertFalse(CaptureCardKind.allCases.contains { $0.rawValue == "autoContext" })
    }

    func testOriginFixturesKeepKindStableAcrossAllOrigins() {
        let origins = Set(CaptureCardLabFixtures.origins.compactMap(\.origin))
        let kinds = Set(CaptureCardLabFixtures.origins.map(\.kind))

        XCTAssertEqual(origins, Set(CaptureArtifactOrigin.allCases))
        XCTAssertEqual(kinds, [.place])
    }

    func testOriginFixturesDoNotSmuggleSourceIntoProductionMetadata() {
        for item in CaptureCardLabFixtures.origins {
            XCTAssertNil(item.metadata)
            for origin in CaptureArtifactOrigin.allCases {
                XCTAssertFalse(item.detail.localizedCaseInsensitiveContains(origin.rawValue))
                XCTAssertFalse(item.detail.localizedCaseInsensitiveContains(origin.captureBadgeLabel))
            }
        }
    }

    func testWeatherVisualStyleResolutionUsesStableSymbols() {
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "Sunny").symbolName, "sun.max.fill")
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "Clear", isNight: true), .clearNight)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "Heavy rain"), .heavyRain)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "Snow"), .snow)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "Fog"), .fog)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "Breezy", windSpeedKmh: 44), .wind)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "Unknown"), .unknown)
    }

    func testWeatherVisualStyleResolutionUsesOfficialConditionCodes() {
        let officialCodes = [
            "blowingDust",
            "clear",
            "cloudy",
            "foggy",
            "haze",
            "mostlyClear",
            "mostlyCloudy",
            "partlyCloudy",
            "smoky",
            "breezy",
            "windy",
            "drizzle",
            "heavyRain",
            "isolatedThunderstorms",
            "rain",
            "sunShowers",
            "scatteredThunderstorms",
            "strongStorms",
            "thunderstorms",
            "frigid",
            "hail",
            "hot",
            "flurries",
            "sleet",
            "snow",
            "sunFlurries",
            "wintryMix",
            "blizzard",
            "blowingSnow",
            "freezingDrizzle",
            "freezingRain",
            "heavySnow",
            "hurricane",
            "tropicalStorm",
        ]

        for code in officialCodes {
            XCTAssertNotEqual(
                CaptureWeatherVisualStyle.resolve(conditionCode: code),
                .unknown,
                "Expected official WeatherKit condition \(code) to resolve."
            )
        }
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(conditionCode: "mostlyClear", isDaylight: true), .sunny)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(conditionCode: "mostlyClear", isDaylight: false), .clearNight)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(conditionCode: "sunShowers"), .rain)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(conditionCode: "wintryMix"), .snow)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(conditionCode: "hurricane"), .thunderstorm)
    }

    func testWeatherVisualStyleFallbackHandlesChineseConditions() {
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "大部晴朗无云"), .sunny)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "大部多云"), .cloudy)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "雷阵雨"), .thunderstorm)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "雨夹雪"), .snow)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "霾"), .fog)
    }

    func testWeatherVisualStyleMotionMappingIsStable() {
        XCTAssertEqual(CaptureWeatherVisualStyle.sunny.symbolMotion, .pulse)
        XCTAssertEqual(CaptureWeatherVisualStyle.rain.symbolMotion, .variableColor)
        XCTAssertEqual(CaptureWeatherVisualStyle.snow.symbolMotion, .variableColor)
        XCTAssertEqual(CaptureWeatherVisualStyle.thunderstorm.motionPattern, .thunderstorm)
        XCTAssertEqual(CaptureWeatherVisualStyle.fog.motionPattern, .fogDrift)
        XCTAssertEqual(CaptureWeatherVisualStyle.wind.motionPattern, .windFlow)
        XCTAssertEqual(CaptureWeatherVisualStyle.rain.resolvedMotionPattern(reduceMotion: true), .staticPattern)
        XCTAssertEqual(CaptureWeatherVisualStyle.rain.resolvedMotionPattern(reduceMotion: false), .rainFall)
    }

    func testWeatherAtmosphereSpecMappingIsStable() {
        XCTAssertEqual(CaptureWeatherVisualStyle.sunny.atmosphereSpec.palette, .warmLight)
        XCTAssertEqual(CaptureWeatherVisualStyle.clearNight.atmosphereSpec.palette, .night)
        XCTAssertEqual(CaptureWeatherVisualStyle.heavyRain.atmosphereSpec.motionPattern, .heavyRainFall)
        XCTAssertEqual(CaptureWeatherVisualStyle.thunderstorm.atmosphereSpec.palette, .storm)
        XCTAssertEqual(CaptureWeatherVisualStyle.fog.atmosphereSpec.motionPattern, .fogDrift)
        XCTAssertEqual(CaptureWeatherVisualStyle.unknown.atmosphereSpec.motionPattern, .staticPattern)
    }

    func testWeatherAtmosphereSpecReduceMotionUsesStaticPattern() {
        let rainy = CaptureWeatherVisualStyle.rain.resolvedAtmosphereSpec(reduceMotion: false)
        let reduced = CaptureWeatherVisualStyle.rain.resolvedAtmosphereSpec(reduceMotion: true)

        XCTAssertEqual(rainy.motionPattern, .rainFall)
        XCTAssertEqual(reduced.motionPattern, .staticPattern)
        XCTAssertLessThanOrEqual(reduced.intensity, 0.42)
    }

    func testProductionProvenanceDisplayShowsOnlyNonManualCompactSourceLabels() {
        XCTAssertNil(CaptureCardProvenanceDisplayMode.production.visual(for: .manual, provenance: nil))
        XCTAssertNil(CaptureCardProvenanceDisplayMode.production.visual(for: .manual, provenance: .manualComposer))

        let journaling = CaptureProvenance.external(
            sourceKind: .journalingSuggestion,
            sourceDisplayName: "Apple Journaling"
        )
        let journalingVisual = CaptureCardProvenanceDisplayMode.production.visual(for: .imported, provenance: journaling)
        XCTAssertEqual(journalingVisual?.label, "Apple Journaling")
        XCTAssertEqual(journalingVisual?.symbolName, CaptureProvenanceSourceKind.journalingSuggestion.symbolName)
        XCTAssertEqual(journalingVisual?.isCompact, true)
    }

    func testDebugProvenanceDisplayShowsFullLabels() {
        for origin in CaptureArtifactOrigin.allCases {
            let visual = CaptureCardProvenanceDisplayMode.debug.visual(for: origin, provenance: nil)
            XCTAssertEqual(visual?.label, origin.captureBadgeLabel)
            XCTAssertNil(visual?.symbolName)
            XCTAssertEqual(visual?.isCompact, false)
        }

        let provenance = CaptureProvenance.external(
            sourceKind: .shareSheet,
            importSessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            sourceDisplayName: "Share"
        )
        let provenanceVisual = CaptureCardProvenanceDisplayMode.debug.visual(for: .imported, provenance: provenance)
        XCTAssertEqual(provenanceVisual?.label, provenance.compactDebugLabel)
        XCTAssertEqual(provenanceVisual?.symbolName, CaptureProvenanceSourceKind.shareSheet.symbolName)
        XCTAssertEqual(provenanceVisual?.isCompact, false)

        XCTAssertNil(CaptureCardProvenanceDisplayMode.hidden.visual(for: .context, provenance: provenance))
    }

    func testDraftMappingPreservesWeatherMusicAndPlaceKinds() {
        let artworkData = makeImageData(color: .systemIndigo)
        let weatherDraft = CaptureArtifactDraft.weather(
            condition: "Rain",
            temperatureCelsius: 18,
            humidity: 0.8,
            windSpeedKmh: 12,
            uvIndex: 2,
            latitude: 31.2,
            longitude: 121.4,
            conditionCode: "rain",
            symbolName: "cloud.rain.fill",
            isDaylight: true,
            origin: .context
        )
        let weatherCard = CaptureCardItem(draft: weatherDraft)
        XCTAssertEqual(weatherCard.kind, .weather)
        XCTAssertEqual(weatherCard.origin, .context)
        XCTAssertEqual(weatherCard.title, captureWeatherTemperatureTitle(18))
        XCTAssertEqual(weatherCard.detail, "Rain")
        XCTAssertEqual(weatherCard.metadata, captureWeatherMetadata(humidity: 0.8, windSpeedKmh: 12, uvIndex: 2))
        guard case let .weather(weatherPayload) = weatherCard.payload else {
            return XCTFail("Expected weather payload.")
        }
        XCTAssertEqual(weatherPayload.style, .rain)
        XCTAssertEqual(weatherPayload.conditionCode, "rain")
        XCTAssertEqual(weatherPayload.symbolName, "cloud.rain.fill")
        XCTAssertEqual(weatherPayload.isDaylight, true)

        let weatherAttachment = CaptureComposerAttachmentItem.staged(index: 0, draft: weatherDraft)
        let weatherCardFromAttachment = CaptureCardItem(attachment: weatherAttachment)
        XCTAssertEqual(weatherCardFromAttachment.title, captureWeatherTemperatureTitle(18))
        XCTAssertEqual(weatherCardFromAttachment.detail, "Rain")
        XCTAssertEqual(weatherCardFromAttachment.metadata, captureWeatherMetadata(humidity: 0.8, windSpeedKmh: 12, uvIndex: 2))
        guard case let .weather(weatherAttachmentPayload) = weatherCardFromAttachment.payload else {
            return XCTFail("Expected weather payload.")
        }
        XCTAssertEqual(weatherAttachmentPayload.conditionCode, "rain")
        XCTAssertEqual(weatherAttachmentPayload.symbolName, "cloud.rain.fill")
        XCTAssertEqual(weatherAttachmentPayload.isDaylight, true)

        let musicCard = CaptureCardItem(
            draft: .music(
                trackName: "Track",
                artistName: "Artist",
                albumName: "Album",
                durationSeconds: 180,
                artworkURL: nil,
                artworkData: artworkData,
                origin: .context
            ),
            musicPlaybackState: .playing
        )
        XCTAssertEqual(musicCard.kind, .music)
        XCTAssertEqual(musicCard.origin, .context)
        XCTAssertEqual(musicCard.title, "Track")
        XCTAssertEqual(musicCard.detail, "Artist · Album")
        guard case let .music(musicPayload) = musicCard.payload else {
            return XCTFail("Expected music payload.")
        }
        XCTAssertEqual(musicPayload.playbackState, .playing)
        XCTAssertEqual(musicPayload.artworkData, artworkData)
        XCTAssertFalse(musicCard.isSelected)
        XCTAssertTrue(musicCard.isRemovable)

        let musicAttachment = CaptureComposerAttachmentItem.staged(index: 1, draft: .music(
            trackName: "Track",
            artistName: "Artist",
            albumName: "Album",
            durationSeconds: 180,
            artworkURL: nil,
            artworkData: artworkData,
            origin: .manual
        ))
        let musicCardFromAttachment = CaptureCardItem(attachment: musicAttachment)
        XCTAssertEqual(musicCardFromAttachment.title, "Track")
        XCTAssertEqual(musicCardFromAttachment.detail, "Artist · Album")

        let placeCard = CaptureCardItem(draft: .location(
            title: "Place",
            summary: "Address",
            latitude: 31.2,
            longitude: 121.4,
            origin: .manual
        ))
        XCTAssertEqual(placeCard.kind, .place)
        XCTAssertEqual(placeCard.origin, .manual)
        XCTAssertNil(placeCard.metadata)
        guard case let .place(placePayload) = placeCard.payload else {
            return XCTFail("Expected place payload.")
        }
        XCTAssertNil(placePayload.mapSnapshotData)
    }

    func testMusicSearchResultStateDoesNotChangeManualOrigin() {
        let card = CaptureCardItem(
            draft: .music(
                trackName: "Search result",
                artistName: "Artist",
                albumName: "Album",
                durationSeconds: 200,
                artworkURL: nil,
                origin: .manual
            ),
            musicPlaybackState: .searchResult
        )

        XCTAssertEqual(card.kind, .music)
        XCTAssertEqual(card.origin, .manual)
        guard case let .music(payload) = card.payload else {
            return XCTFail("Expected music payload.")
        }
        XCTAssertEqual(payload.playbackState, .searchResult)
    }

    func testMusicStyleLabelsUseLayoutNamesOnly() {
        XCTAssertEqual(CaptureMusicCardStyle.compactRow.label, String(localized: "capture.card.music.style.compactRow"))
        XCTAssertEqual(CaptureMusicCardStyle.compactTile.label, String(localized: "capture.card.music.style.compactTile"))
        XCTAssertEqual(CaptureMusicCardStyle.cover.label, String(localized: "capture.card.music.style.cover"))
        XCTAssertEqual(CaptureMusicCardStyle.auto.label, String(localized: "capture.card.music.style.auto"))
        XCTAssertFalse(CaptureMusicCardStyle.compactRow.label.localizedCaseInsensitiveContains("compact"))
        XCTAssertFalse(CaptureMusicCardStyle.compactTile.label.localizedCaseInsensitiveContains("compact"))
        XCTAssertFalse(CaptureMusicCardStyle.compactRow.label.contains("紧凑"))
        XCTAssertFalse(CaptureMusicCardStyle.compactTile.label.contains("紧凑"))
    }

    func testAudioDraftMappingUsesTranscriptAsPrimaryDetail() {
        let card = CaptureCardItem(draft: .audio(
            title: "Voice",
            summary: "Audio summary",
            filename: "voice.caf",
            audioData: Data("audio".utf8),
            transcriptionText: "This is the useful transcript preview.",
            origin: .manual
        ))

        XCTAssertEqual(card.kind, .audio)
        XCTAssertEqual(card.detail, "This is the useful transcript preview.")
        XCTAssertEqual(card.metadata, "voice.caf")
    }

    func testMusicCardStyleResolutionUsesCompactFallbackWithoutArtwork() {
        let noArtwork = CaptureCardItem(payload: .music(CaptureMusicCardPayload()), title: "Track", detail: "Artist")
        let withArtwork = CaptureCardItem(
            payload: .music(CaptureMusicCardPayload(artworkData: makeImageData(color: .purple))),
            title: "Track",
            detail: "Artist"
        )

        XCTAssertEqual(CaptureMusicCardStyle.compactRow.resolved(for: noArtwork), .compactRow)
        XCTAssertEqual(CaptureMusicCardStyle.compactTile.resolved(for: noArtwork), .compactTile)
        XCTAssertEqual(CaptureMusicCardStyle.cover.resolved(for: noArtwork), .cover)
        XCTAssertEqual(CaptureMusicCardStyle.cover.resolved(for: withArtwork), .cover)
        XCTAssertEqual(CaptureMusicCardStyle.auto.resolved(for: withArtwork), .compactRow)
    }

    func testPhotoGroupFixturesKeepPhotoKindAndStyles() {
        let groups = CaptureCardLabFixtures.photoGroups

        let payloads: [CapturePhotoCardPayload] = groups.compactMap { item in
            guard case let .photo(payload) = item.payload else {
                return nil
            }
            return payload
        }

        XCTAssertEqual(payloads.first?.photoCount, 1)
        XCTAssertTrue(groups.allSatisfy { $0.kind == .photo })
        XCTAssertEqual(Set(payloads.compactMap(\.groupStyle)), Set(CapturePhotoGroupStyle.allCases))
        XCTAssertTrue(payloads.dropFirst().allSatisfy { $0.photoCount > 1 })
    }

    func testCaptureCardPaletteUsesWeatherPhotoAndMusicSources() {
        let weather = CaptureCardPalette.resolve(
            for: CaptureCardItem(payload: .weather(CaptureWeatherCardPayload(style: .rain)), title: "Rain", detail: "Rain"),
            highContrast: false
        )
        XCTAssertEqual(weather.source, .weather)

        let music = CaptureCardPalette.resolve(
            for: CaptureCardItem(
                payload: .music(CaptureMusicCardPayload(artworkPalette: MusicArtworkPalette(
                    backgroundColorHex: "#123456",
                    primaryTextColorHex: "#FFFFFF",
                    secondaryTextColorHex: "#DDDDDD"
                ))),
                title: "Track",
                detail: "Artist"
            ),
            highContrast: false
        )
        XCTAssertEqual(music.source, .musicArtwork)

        let photo = CaptureCardPalette.resolve(
            for: CaptureCardItem(payload: .photo(CapturePhotoCardPayload(thumbnailData: makeImageData(color: .systemPink))), detail: "Photo"),
            highContrast: false
        )
        XCTAssertEqual(photo.source, .photoSample)
    }

    func testMapLegibilityChoosesLightTextForDarkSnapshot() {
        let data = makeImageData(color: .black)

        XCTAssertEqual(CaptureMapLegibilityStyle.resolve(snapshotData: data), .lightText)
    }

    func testMapLegibilityChoosesDarkTextForLightSnapshot() {
        let data = makeImageData(color: .white)

        XCTAssertEqual(CaptureMapLegibilityStyle.resolve(snapshotData: data), .darkText)
    }

    func testMapLegibilityUsesFallbackWithoutSnapshot() {
        XCTAssertEqual(CaptureMapLegibilityStyle.resolve(snapshotData: nil), .fallback)
        XCTAssertEqual(CaptureMapLegibilityStyle.resolve(snapshotData: Data("bad-image".utf8)), .fallback)
    }

    func testCardLegibilityChoosesTextToneForImageData() {
        XCTAssertEqual(
            CaptureCardLegibility.imageData(makeImageData(color: .black), highContrast: false).tone,
            .lightText
        )
        XCTAssertEqual(
            CaptureCardLegibility.imageData(makeImageData(color: .white), highContrast: false).tone,
            .darkText
        )
    }

    func testCardLegibilityChoosesTextToneForMapAndWeather() {
        XCTAssertEqual(
            CaptureCardLegibility.map(snapshotData: makeImageData(color: .black), isPrivacyEnabled: false, highContrast: false).tone,
            .lightText
        )
        XCTAssertEqual(
            CaptureCardLegibility.map(snapshotData: makeImageData(color: .white), isPrivacyEnabled: false, highContrast: false).tone,
            .darkText
        )
        XCTAssertEqual(
            CaptureCardLegibility.weather(style: .thunderstorm, highContrast: false).tone,
            .lightText
        )
        XCTAssertEqual(
            CaptureCardLegibility.weather(style: .sunny, highContrast: false).tone,
            .darkText
        )
    }

    func testCardLegibilityUsesMusicPaletteWithoutMaterialDependency() {
        let palette = CaptureCardPalette.resolve(
            for: CaptureCardItem(
                payload: .music(CaptureMusicCardPayload(artworkPalette: MusicArtworkPalette(
                    backgroundColorHex: "#101820",
                    primaryTextColorHex: "#FFFFFF",
                    secondaryTextColorHex: "#CCCCCC"
                ))),
                title: "Track",
                detail: "Artist"
            ),
            highContrast: false
        )
        let legibility = CaptureCardLegibility.palette(palette, highContrast: false)

        XCTAssertEqual(legibility.tone, .semantic)
        XCTAssertFalse(legibility.scrimColors.isEmpty)
    }

    private func makeImageData(color: UIColor) -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        return image.pngData() ?? Data()
    }
}
