import Foundation

enum CaptureCardLabFixtures {
    static let allTypes: [CaptureCardItem] = [
        CaptureCardItem(
            id: "fixture-photo",
            payload: .photo(CapturePhotoCardPayload(
                mediaDimensions: ArtifactMediaDimensions(width: 1440, height: 1800),
                photoCount: 3
            )),
            title: String(localized: "debug.captureCardLab.fixture.photo.title"),
            detail: String(localized: "debug.captureCardLab.fixture.photo.detail"),
            metadata: String(format: String(localized: "capture.card.photo.count.format"), 3),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-video",
            payload: .video(CaptureVideoCardPayload(
                durationSeconds: 18,
                mediaDimensions: ArtifactMediaDimensions(width: 1920, height: 1080)
            )),
            title: "Video",
            detail: "Media-only video fixture with centered play control",
            metadata: "0:18",
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-live-photo",
            payload: .livePhoto(CaptureLivePhotoCardPayload(
                mediaDimensions: ArtifactMediaDimensions(width: 3024, height: 4032)
            )),
            title: "Live Photo",
            detail: "Media-only Live Photo fixture with non-text glyph",
            metadata: "Live Photo",
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-audio",
            payload: .audio(CaptureAudioCardPayload(durationSeconds: 74)),
            title: String(localized: "debug.captureCardLab.fixture.audio.title"),
            detail: String(localized: "debug.captureCardLab.fixture.audio.detail"),
            metadata: String(localized: "debug.captureCardLab.fixture.audio.metadata"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-place",
            payload: .place(CapturePlaceCardPayload(latitude: 31.218, longitude: 121.446)),
            origin: .context,
            title: String(localized: "debug.captureCardLab.fixture.place.title"),
            detail: String(localized: "debug.captureCardLab.fixture.place.detail"),
            metadata: "31.218, 121.446",
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-weather",
            payload: .weather(CaptureWeatherCardPayload(style: .cloudy)),
            origin: .context,
            title: String(localized: "capture.card.weather.cloudy"),
            detail: "23°C · light wind · humidity 61%",
            metadata: String(localized: "debug.captureCardLab.fixture.weather.metadata"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-music",
            payload: .music(CaptureMusicCardPayload(durationSeconds: 244, playbackState: .playing)),
            origin: .context,
            title: "Midnight City",
            detail: "M83 · Hurry Up, We're Dreaming",
            metadata: String(localized: "capture.card.music.nowPlaying"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-link",
            payload: .link(CaptureLinkCardPayload()),
            title: "SwiftUI ToolbarItemPlacement",
            detail: "developer.apple.com/documentation/swiftui/toolbaritemplacement",
            metadata: String(localized: "debug.captureCardLab.fixture.link.metadata"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-todo",
            payload: .todo(CaptureTodoCardPayload()),
            title: String(localized: "debug.captureCardLab.fixture.todo.title"),
            detail: String(localized: "debug.captureCardLab.fixture.todo.detail"),
            metadata: String(localized: "capture.card.kind.todo"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-journaling-suggestion",
            payload: .journalingSuggestion(CaptureJournalingSuggestionCardPayload(
                artifactCount: 5,
                affectCount: 1,
                photoCount: 2,
                videoCount: 1,
                livePhotoCount: 1,
                locationCount: 1
            )),
            origin: .imported,
            title: "Journaling Suggestion",
            detail: "5 items · 1 mood",
            metadata: "Journaling",
            isRemovable: true
        ),
    ]

    static let origins: [CaptureCardItem] = CaptureArtifactOrigin.allCases.map { origin in
        CaptureCardItem(
            id: "origin-\(origin.rawValue)",
            payload: .place(CapturePlaceCardPayload(latitude: 31.218, longitude: 121.446)),
            origin: origin,
            title: String(localized: "debug.captureCardLab.origins.title"),
            detail: String(localized: "debug.captureCardLab.origins.detail"),
            metadata: nil,
            isSelected: false,
            isRemovable: false
        )
    }

    static let states: [CaptureCardItem] = [
        CaptureCardItem(
            id: "state-normal",
            payload: .music(CaptureMusicCardPayload()),
            title: String(localized: "debug.captureCardLab.state.normal.title"),
            detail: String(localized: "debug.captureCardLab.state.normal.detail"),
            metadata: String(localized: "debug.captureCardLab.state.normal.metadata")
        ),
        CaptureCardItem(
            id: "state-selected",
            payload: .weather(CaptureWeatherCardPayload()),
            title: String(localized: "debug.captureCardLab.state.selected.title"),
            detail: String(localized: "debug.captureCardLab.state.selected.detail"),
            metadata: String(localized: "capture.card.selected"),
            isSelected: true
        ),
        CaptureCardItem(
            id: "state-loading",
            payload: .status(CaptureStatusCardPayload()),
            origin: nil,
            state: .loading,
            title: String(localized: "debug.captureCardLab.state.loading.title"),
            detail: String(localized: "debug.captureCardLab.state.loading.detail"),
            metadata: String(localized: "capture.card.kind.working")
        ),
        CaptureCardItem(
            id: "state-error",
            payload: .status(CaptureStatusCardPayload()),
            origin: nil,
            state: .error,
            title: String(localized: "debug.captureCardLab.state.error.title"),
            detail: String(localized: "debug.captureCardLab.state.error.detail"),
            metadata: String(localized: "debug.captureCardLab.state.error.metadata")
        ),
        CaptureCardItem(
            id: "state-disabled",
            payload: .link(CaptureLinkCardPayload()),
            state: .disabled,
            title: String(localized: "debug.captureCardLab.state.disabled.title"),
            detail: String(localized: "debug.captureCardLab.state.disabled.detail"),
            metadata: String(localized: "capture.card.music.unavailable")
        ),
        CaptureCardItem(
            id: "state-removable",
            payload: .photo(CapturePhotoCardPayload()),
            title: String(localized: "debug.captureCardLab.state.removable.title"),
            detail: String(localized: "debug.captureCardLab.state.removable.detail"),
            metadata: String(localized: "debug.captureCardLab.state.removable.metadata"),
            isRemovable: true
        ),
    ]

    static let edgeCases: [CaptureCardItem] = [
        CaptureCardItem(
            id: "edge-long",
            payload: .audio(CaptureAudioCardPayload(durationSeconds: 724)),
            title: nil,
            detail: String(localized: "debug.captureCardLab.edge.longTranscript.detail"),
            metadata: "12:04",
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-no-image",
            payload: .photo(CapturePhotoCardPayload()),
            title: nil,
            detail: String(localized: "debug.captureCardLab.edge.noImage.detail"),
            metadata: String(localized: "debug.captureCardLab.status.processing"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-manual-music",
            payload: .music(CaptureMusicCardPayload()),
            origin: .manual,
            title: String(localized: "debug.captureCardLab.edge.manualMusic.title"),
            detail: String(localized: "debug.captureCardLab.edge.manualMusic.detail"),
            metadata: String(localized: "capture.card.music.searchResult")
        ),
        CaptureCardItem(
            id: "edge-context-weather",
            payload: .weather(CaptureWeatherCardPayload(style: .rain)),
            origin: .context,
            title: String(localized: "capture.card.weather.rain"),
            detail: "16°C · umbrella weather",
            metadata: "UV 2",
            isSelected: false
        ),
        CaptureCardItem(
            id: "edge-weather-zh-mostly-clear",
            payload: .weather(CaptureWeatherCardPayload(style: .resolve(condition: "大部晴朗无云"))),
            origin: .context,
            title: "大部晴朗无云",
            detail: "21°C · 湿度 48%",
            metadata: "UV 4",
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-weather-zh-mostly-cloudy",
            payload: .weather(CaptureWeatherCardPayload(style: .resolve(condition: "大部多云"))),
            origin: .context,
            title: "大部多云",
            detail: "19°C · 湿度 64%",
            metadata: "UV 2",
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-weather-zh-thunder-shower",
            payload: .weather(CaptureWeatherCardPayload(style: .resolve(condition: "雷阵雨"))),
            origin: .context,
            title: "雷阵雨",
            detail: "17°C · 湿度 86%",
            metadata: "UV 1",
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-weather-zh-wintry-mix",
            payload: .weather(CaptureWeatherCardPayload(style: .resolve(condition: "雨夹雪"))),
            origin: .context,
            title: "雨夹雪",
            detail: "1°C · 湿度 82%",
            metadata: "UV 0",
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-weather-zh-haze",
            payload: .weather(CaptureWeatherCardPayload(style: .resolve(condition: "霾"))),
            origin: .context,
            title: "霾",
            detail: "12°C · 湿度 58%",
            metadata: "UV 1",
            isRemovable: true
        ),
    ]

    static let status: [CaptureCardItem] = [
        CaptureCardItem(
            id: "status-context",
            payload: .status(CaptureStatusCardPayload()),
            origin: nil,
            state: .loading,
            title: String(localized: "debug.captureCardLab.status.context.title"),
            detail: String(localized: "debug.captureCardLab.status.context.detail")
        ),
        CaptureCardItem(
            id: "status-empty-context",
            payload: .status(CaptureStatusCardPayload()),
            origin: nil,
            title: String(localized: "debug.captureCardLab.status.emptyContext.title"),
            detail: String(localized: "debug.captureCardLab.status.emptyContext.detail")
        ),
        CaptureCardItem(
            id: "status-photo-processing",
            payload: .status(CaptureStatusCardPayload()),
            origin: nil,
            state: .loading,
            title: String(localized: "debug.captureCardLab.status.photoProcessing.title"),
            detail: String(localized: "debug.captureCardLab.status.photoProcessing.detail")
        ),
        CaptureCardItem(
            id: "status-voice-refining",
            payload: .status(CaptureStatusCardPayload()),
            origin: nil,
            state: .loading,
            title: String(localized: "debug.captureCardLab.status.voiceRefining.title"),
            detail: String(localized: "debug.captureCardLab.status.voiceRefining.detail")
        ),
    ]

    static let photoGroups: [CaptureCardItem] = [
        CaptureCardItem(
            id: "photo-single",
            payload: .photo(CapturePhotoCardPayload(
                mediaDimensions: ArtifactMediaDimensions(width: 1440, height: 1800),
                photoCount: 1
            )),
            title: String(localized: "debug.captureCardLab.photo.single.title"),
            detail: String(localized: "debug.captureCardLab.photo.single.detail"),
            metadata: String(format: String(localized: "capture.card.photo.count.format"), 1)
        ),
        CaptureCardItem(
            id: "photo-group-mosaic",
            payload: .photo(CapturePhotoCardPayload(
                mediaDimensions: ArtifactMediaDimensions(width: 1600, height: 1200),
                photoCount: 4
            )),
            title: String(localized: "debug.captureCardLab.photo.mosaic.title"),
            detail: String(localized: "debug.captureCardLab.photo.mosaic.detail"),
            metadata: String(format: String(localized: "capture.card.photo.count.format"), 4)
        ),
        CaptureCardItem(
            id: "photo-group-stack",
            payload: .photo(CapturePhotoCardPayload(
                mediaDimensions: ArtifactMediaDimensions(width: 1200, height: 1600),
                photoCount: 5
            )),
            title: String(localized: "debug.captureCardLab.photo.stack.title"),
            detail: String(localized: "debug.captureCardLab.photo.stack.detail"),
            metadata: String(format: String(localized: "capture.card.photo.count.format"), 5)
        ),
        CaptureCardItem(
            id: "photo-group-carousel",
            payload: .photo(CapturePhotoCardPayload(
                mediaDimensions: ArtifactMediaDimensions(width: 1920, height: 1080),
                photoCount: 8
            )),
            title: String(localized: "debug.captureCardLab.photo.carousel.title"),
            detail: String(localized: "debug.captureCardLab.photo.carousel.detail"),
            metadata: String(format: String(localized: "capture.card.photo.count.format"), 8)
        ),
    ]

    static let musicFixtures: [CaptureCardItem] = [
        CaptureCardItem(
            id: "music-fixture-m83",
            payload: .music(CaptureMusicCardPayload(durationSeconds: 244, playbackState: .playing)),
            origin: .context,
            title: "Midnight City",
            detail: "M83 · Hurry Up, We're Dreaming",
            metadata: String(localized: "capture.card.music.nowPlaying"),
            isSelected: true
        ),
        CaptureCardItem(
            id: "music-fixture-japanese-house",
            payload: .music(CaptureMusicCardPayload(durationSeconds: 220, playbackState: .searchResult)),
            origin: .manual,
            title: "Sunshine Baby",
            detail: "The Japanese House · In the End It Always Does",
            metadata: String(localized: "capture.card.music.searchResult"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "music-fixture-paused",
            payload: .music(CaptureMusicCardPayload(durationSeconds: 184, playbackState: .paused)),
            origin: .context,
            title: String(localized: "debug.captureCardLab.music.paused.title"),
            detail: String(localized: "debug.captureCardLab.music.paused.detail"),
            metadata: String(localized: "capture.card.music.paused")
        ),
    ]

    static let placeScenarios: [CapturePlaceLabScenario] = [
        CapturePlaceLabScenario(
            id: "current-place",
            label: String(localized: "debug.captureCardLab.place.current.label"),
            item: CaptureCardItem(
                id: "place-current",
                payload: .place(CapturePlaceCardPayload(latitude: 31.218, longitude: 121.446)),
                origin: .context,
                title: String(localized: "debug.captureCardLab.fixture.place.title"),
                detail: String(localized: "debug.captureCardLab.place.current.detail"),
                metadata: "31.218, 121.446",
                isRemovable: true
            )
        ),
        CapturePlaceLabScenario(
            id: "manual-pin",
            label: String(localized: "debug.captureCardLab.place.manual.label"),
            item: CaptureCardItem(
                id: "place-manual",
                payload: .place(CapturePlaceCardPayload(latitude: 31.230, longitude: 121.474)),
                origin: .manual,
                title: String(localized: "debug.captureCardLab.place.manual.title"),
                detail: String(localized: "debug.captureCardLab.place.manual.detail"),
                metadata: "31.230, 121.474",
                isRemovable: true
            )
        ),
        CapturePlaceLabScenario(
            id: "search-result",
            label: String(localized: "capture.card.music.searchResult"),
            item: CaptureCardItem(
                id: "place-search",
                payload: .place(CapturePlaceCardPayload(latitude: 31.207, longitude: 121.444)),
                origin: .manual,
                title: "Shanghai Library",
                detail: "1555 Huaihai Middle Road",
                metadata: String(localized: "capture.action.search"),
                isRemovable: true
            )
        ),
        CapturePlaceLabScenario(
            id: "same-name-far",
            label: String(localized: "debug.captureCardLab.place.sameNameFar.label"),
            item: CaptureCardItem(
                id: "place-same-name-far",
                payload: .place(CapturePlaceCardPayload(latitude: 37.776, longitude: -122.423)),
                origin: .inferred,
                title: "Blue Bottle Coffee",
                detail: String(localized: "debug.captureCardLab.place.sameNameFar.detail"),
                metadata: String(localized: "debug.captureCardLab.place.sameNameFar.metadata")
            )
        ),
        CapturePlaceLabScenario(
            id: "near-different-name",
            label: String(localized: "debug.captureCardLab.place.nearDifferentName.label"),
            item: CaptureCardItem(
                id: "place-near-different-name",
                payload: .place(CapturePlaceCardPayload(latitude: 31.2184, longitude: 121.4463)),
                origin: .context,
                title: String(localized: "debug.captureCardLab.place.nearDifferentName.title"),
                detail: String(localized: "debug.captureCardLab.place.nearDifferentName.detail"),
                metadata: String(localized: "debug.captureCardLab.place.nearDifferentName.metadata"),
                isRemovable: true
            )
        ),
        CapturePlaceLabScenario(
            id: "no-coordinate",
            label: String(localized: "debug.captureCardLab.place.noCoordinate.label"),
            item: CaptureCardItem(
                id: "place-no-coordinate",
                payload: .place(CapturePlaceCardPayload()),
                origin: .imported,
                title: String(localized: "debug.captureCardLab.place.noCoordinate.title"),
                detail: String(localized: "debug.captureCardLab.place.noCoordinate.detail"),
                metadata: String(localized: "debug.captureCardLab.place.noCoordinate.metadata")
            )
        ),
    ]
}

struct CapturePlaceLabScenario: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let item: CaptureCardItem
}
