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

    func testWeatherVisualStyleResolutionUsesStableSymbols() {
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "Sunny").symbolName, "sun.max.fill")
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "Clear", isNight: true), .clearNight)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "Heavy rain"), .heavyRain)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "Snow"), .snow)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "Fog"), .fog)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "Breezy", windSpeedKmh: 44), .wind)
        XCTAssertEqual(CaptureWeatherVisualStyle.resolve(condition: "Unknown"), .unknown)
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
        let weatherCard = CaptureCardItem(draft: .weather(
            condition: "Rain",
            temperatureCelsius: 18,
            humidity: 0.8,
            windSpeedKmh: 12,
            uvIndex: 2,
            latitude: 31.2,
            longitude: 121.4,
            origin: .context
        ))
        XCTAssertEqual(weatherCard.kind, .weather)
        XCTAssertEqual(weatherCard.origin, .context)
        XCTAssertEqual(weatherCard.weatherStyle, .rain)

        let musicCard = CaptureCardItem(
            draft: .music(
                trackName: "Track",
                artistName: "Artist",
                albumName: "Album",
                durationSeconds: 180,
                artworkURL: nil,
                origin: .context
            ),
            musicPlaybackState: .playing
        )
        XCTAssertEqual(musicCard.kind, .music)
        XCTAssertEqual(musicCard.origin, .context)
        XCTAssertEqual(musicCard.musicPlaybackState, .playing)
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
