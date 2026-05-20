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

    func testOnlyNormalCardsDisplaySelection() {
        for state in CaptureCardVisualState.allCases {
            let card = CaptureCardItem(
                kind: .weather,
                state: state,
                detail: "State test",
                isSelected: true
            )

            XCTAssertEqual(card.displaysSelection, state == .normal)
        }
    }

    func testTransientCardsDoNotAllowPrimaryAction() {
        XCTAssertTrue(CaptureCardItem(kind: .photo, state: .normal, detail: "Ready").allowsPrimaryAction)
        XCTAssertFalse(CaptureCardItem(kind: .photo, state: .loading, detail: "Loading").allowsPrimaryAction)
        XCTAssertFalse(CaptureCardItem(kind: .photo, state: .error, detail: "Failed").allowsPrimaryAction)
        XCTAssertFalse(CaptureCardItem(kind: .photo, state: .disabled, detail: "Unavailable").allowsPrimaryAction)
    }

    func testErrorRemovableCardsKeepRemoveAffordanceButNotSelection() {
        let card = CaptureCardItem(
            kind: .photo,
            state: .error,
            detail: "Upload failed",
            isSelected: true,
            isRemovable: true
        )

        XCTAssertFalse(card.displaysSelection)
        XCTAssertTrue(card.displaysRemoveControl)
    }

    func testRemovableNormalCardsPreferRemoveOverSelectedAffordance() {
        let card = CaptureCardItem(
            kind: .weather,
            state: .normal,
            detail: "Included context",
            isSelected: true,
            isRemovable: true
        )

        XCTAssertFalse(card.displaysSelection)
        XCTAssertTrue(card.displaysRemoveControl)
    }

    func testTopTrailingAvoidanceOnlyAppearsWhenControlsAreVisible() {
        let plain = CaptureCardItem(kind: .link, state: .normal, detail: "Plain")
        let removable = CaptureCardItem(kind: .link, state: .normal, detail: "Remove", isRemovable: true)
        let selected = CaptureCardItem(kind: .link, state: .normal, detail: "Selected", isSelected: true)
        let loading = CaptureCardItem(kind: .link, state: .loading, detail: "Loading")

        XCTAssertEqual(plain.topTrailingAvoidance, 0)
        XCTAssertGreaterThan(removable.topTrailingAvoidance, 0)
        XCTAssertGreaterThan(selected.topTrailingAvoidance, 0)
        XCTAssertGreaterThan(loading.topTrailingAvoidance, 0)
    }

    func testLoadingAndDisabledCardsDoNotDisplayRemoveControl() {
        let loading = CaptureCardItem(kind: .photo, state: .loading, detail: "Processing", isRemovable: true)
        let disabled = CaptureCardItem(kind: .photo, state: .disabled, detail: "Unavailable", isRemovable: true)

        XCTAssertFalse(loading.displaysRemoveControl)
        XCTAssertFalse(disabled.displaysRemoveControl)
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

    func testProductionProvenanceDisplayHidesAllSourceLabels() {
        XCTAssertNil(CaptureCardProvenanceDisplayMode.production.visual(for: .manual))
        XCTAssertNil(CaptureCardProvenanceDisplayMode.production.visual(for: .context))
        XCTAssertNil(CaptureCardProvenanceDisplayMode.production.visual(for: .imported))
        XCTAssertNil(CaptureCardProvenanceDisplayMode.production.visual(for: .inferred))
    }

    func testDebugProvenanceDisplayShowsFullLabels() {
        for origin in CaptureArtifactOrigin.allCases {
            let visual = CaptureCardProvenanceDisplayMode.debug.visual(for: origin)
            XCTAssertEqual(visual?.label, origin.captureBadgeLabel)
            XCTAssertNil(visual?.symbolName)
            XCTAssertEqual(visual?.isCompact, false)
        }

        XCTAssertNil(CaptureCardProvenanceDisplayMode.hidden.visual(for: .context))
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
        XCTAssertEqual(weatherCard.weatherStyle, .rain)
        XCTAssertEqual(weatherCard.weatherConditionCode, "rain")
        XCTAssertEqual(weatherCard.weatherSymbolName, "cloud.rain.fill")
        XCTAssertEqual(weatherCard.weatherIsDaylight, true)

        let weatherAttachment = CaptureComposerAttachmentItem.staged(index: 0, draft: weatherDraft)
        let weatherCardFromAttachment = CaptureCardItem(attachment: weatherAttachment)
        XCTAssertEqual(weatherCardFromAttachment.weatherConditionCode, "rain")
        XCTAssertEqual(weatherCardFromAttachment.weatherSymbolName, "cloud.rain.fill")
        XCTAssertEqual(weatherCardFromAttachment.weatherIsDaylight, true)

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
        XCTAssertEqual(musicCard.musicPlaybackState, .playing)
        XCTAssertEqual(musicCard.thumbnailData, artworkData)
        XCTAssertFalse(musicCard.isSelected)
        XCTAssertTrue(musicCard.isRemovable)

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
        XCTAssertNil(placeCard.mapSnapshotData)
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
        XCTAssertEqual(card.musicPlaybackState, .searchResult)
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
        let noArtwork = CaptureCardItem(kind: .music, title: "Track", detail: "Artist")
        let withArtwork = CaptureCardItem(
            kind: .music,
            title: "Track",
            detail: "Artist",
            thumbnailData: makeImageData(color: .purple)
        )

        XCTAssertEqual(CaptureMusicCardStyle.compactRow.resolved(for: noArtwork), .compactRow)
        XCTAssertEqual(CaptureMusicCardStyle.compactTile.resolved(for: noArtwork), .compactTile)
        XCTAssertEqual(CaptureMusicCardStyle.cover.resolved(for: noArtwork), .compactRow)
        XCTAssertEqual(CaptureMusicCardStyle.cover.resolved(for: withArtwork), .cover)
        XCTAssertEqual(CaptureMusicCardStyle.auto.resolved(for: withArtwork), .compactRow)
    }

    func testPhotoGroupFixturesKeepPhotoKindAndStyles() {
        let groups = CaptureCardLabFixtures.photoGroups

        XCTAssertEqual(groups.first?.photoCount, 1)
        XCTAssertTrue(groups.allSatisfy { $0.kind == .photo })
        XCTAssertEqual(Set(groups.compactMap(\.photoGroupStyle)), Set(CapturePhotoGroupStyle.allCases))
        XCTAssertTrue(groups.dropFirst().allSatisfy { $0.photoCount > 1 })
    }

    func testCaptureCardPaletteUsesWeatherPhotoAndMusicSources() {
        let weather = CaptureCardPalette.resolve(
            for: CaptureCardItem(kind: .weather, title: "Rain", detail: "Rain", weatherStyle: .rain),
            highContrast: false
        )
        XCTAssertEqual(weather.source, .weather)

        let music = CaptureCardPalette.resolve(
            for: CaptureCardItem(
                kind: .music,
                title: "Track",
                detail: "Artist",
                artworkPalette: MusicArtworkPalette(
                    backgroundColorHex: "#123456",
                    primaryTextColorHex: "#FFFFFF",
                    secondaryTextColorHex: "#DDDDDD"
                )
            ),
            highContrast: false
        )
        XCTAssertEqual(music.source, .musicArtwork)

        let photo = CaptureCardPalette.resolve(
            for: CaptureCardItem(kind: .photo, detail: "Photo", thumbnailData: makeImageData(color: .systemPink)),
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

    func testMapLegibilityUsesMaterialFallbackWithoutSnapshot() {
        XCTAssertEqual(CaptureMapLegibilityStyle.resolve(snapshotData: nil), .materialFallback)
        XCTAssertEqual(CaptureMapLegibilityStyle.resolve(snapshotData: Data("bad-image".utf8)), .materialFallback)
    }

    private func makeImageData(color: UIColor) -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        return image.pngData() ?? Data()
    }
}
