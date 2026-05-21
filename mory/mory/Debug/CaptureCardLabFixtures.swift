import Foundation

enum CaptureCardLabFixtures {
    static let allTypes: [CaptureCardItem] = [
        CaptureCardItem(
            id: "fixture-photo",
            kind: .photo,
            title: String(localized: "debug.captureCardLab.fixture.photo.title"),
            detail: String(localized: "debug.captureCardLab.fixture.photo.detail"),
            metadata: String(format: String(localized: "capture.card.photo.count.format"), 3),
            photoCount: 3,
            photoGroupStyle: .mosaic,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-audio",
            kind: .audio,
            title: String(localized: "debug.captureCardLab.fixture.audio.title"),
            detail: String(localized: "debug.captureCardLab.fixture.audio.detail"),
            metadata: String(localized: "debug.captureCardLab.fixture.audio.metadata"),
            durationSeconds: 74,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-place",
            kind: .place,
            origin: .context,
            title: String(localized: "debug.captureCardLab.fixture.place.title"),
            detail: String(localized: "debug.captureCardLab.fixture.place.detail"),
            metadata: "31.218, 121.446",
            latitude: 31.218,
            longitude: 121.446,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-weather",
            kind: .weather,
            origin: .context,
            title: String(localized: "capture.card.weather.cloudy"),
            detail: "23°C · light wind · humidity 61%",
            metadata: String(localized: "debug.captureCardLab.fixture.weather.metadata"),
            weatherStyle: .cloudy,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-music",
            kind: .music,
            origin: .context,
            title: "Midnight City",
            detail: "M83 · Hurry Up, We're Dreaming",
            metadata: String(localized: "capture.card.music.nowPlaying"),
            durationSeconds: 244,
            musicPlaybackState: .playing,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-link",
            kind: .link,
            title: "SwiftUI ToolbarItemPlacement",
            detail: "developer.apple.com/documentation/swiftui/toolbaritemplacement",
            metadata: String(localized: "debug.captureCardLab.fixture.link.metadata"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-todo",
            kind: .todo,
            title: String(localized: "debug.captureCardLab.fixture.todo.title"),
            detail: String(localized: "debug.captureCardLab.fixture.todo.detail"),
            metadata: String(localized: "capture.card.kind.todo"),
            isRemovable: true
        ),
    ]

    static let origins: [CaptureCardItem] = CaptureArtifactOrigin.allCases.map { origin in
        CaptureCardItem(
            id: "origin-\(origin.rawValue)",
            kind: .place,
            origin: origin,
            title: String(localized: "debug.captureCardLab.origins.title"),
            detail: String(localized: "debug.captureCardLab.origins.detail"),
            metadata: nil,
            latitude: 31.218,
            longitude: 121.446,
            isSelected: false,
            isRemovable: false
        )
    }

    static let states: [CaptureCardItem] = [
        CaptureCardItem(
            id: "state-normal",
            kind: .music,
            title: String(localized: "debug.captureCardLab.state.normal.title"),
            detail: String(localized: "debug.captureCardLab.state.normal.detail"),
            metadata: String(localized: "debug.captureCardLab.state.normal.metadata")
        ),
        CaptureCardItem(
            id: "state-selected",
            kind: .weather,
            title: String(localized: "debug.captureCardLab.state.selected.title"),
            detail: String(localized: "debug.captureCardLab.state.selected.detail"),
            metadata: String(localized: "capture.card.selected"),
            isSelected: true
        ),
        CaptureCardItem(
            id: "state-loading",
            kind: .status,
            origin: nil,
            state: .loading,
            title: String(localized: "debug.captureCardLab.state.loading.title"),
            detail: String(localized: "debug.captureCardLab.state.loading.detail"),
            metadata: String(localized: "capture.card.kind.working")
        ),
        CaptureCardItem(
            id: "state-error",
            kind: .status,
            origin: nil,
            state: .error,
            title: String(localized: "debug.captureCardLab.state.error.title"),
            detail: String(localized: "debug.captureCardLab.state.error.detail"),
            metadata: String(localized: "debug.captureCardLab.state.error.metadata")
        ),
        CaptureCardItem(
            id: "state-disabled",
            kind: .link,
            state: .disabled,
            title: String(localized: "debug.captureCardLab.state.disabled.title"),
            detail: String(localized: "debug.captureCardLab.state.disabled.detail"),
            metadata: String(localized: "capture.card.music.unavailable")
        ),
        CaptureCardItem(
            id: "state-removable",
            kind: .photo,
            title: String(localized: "debug.captureCardLab.state.removable.title"),
            detail: String(localized: "debug.captureCardLab.state.removable.detail"),
            metadata: String(localized: "debug.captureCardLab.state.removable.metadata"),
            isRemovable: true
        ),
    ]

    static let edgeCases: [CaptureCardItem] = [
        CaptureCardItem(
            id: "edge-long",
            kind: .audio,
            title: nil,
            detail: String(localized: "debug.captureCardLab.edge.longTranscript.detail"),
            metadata: "12:04",
            durationSeconds: 724,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-no-image",
            kind: .photo,
            title: nil,
            detail: String(localized: "debug.captureCardLab.edge.noImage.detail"),
            metadata: String(localized: "debug.captureCardLab.status.processing"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-manual-music",
            kind: .music,
            origin: .manual,
            title: String(localized: "debug.captureCardLab.edge.manualMusic.title"),
            detail: String(localized: "debug.captureCardLab.edge.manualMusic.detail"),
            metadata: String(localized: "capture.card.music.searchResult")
        ),
        CaptureCardItem(
            id: "edge-context-weather",
            kind: .weather,
            origin: .context,
            title: String(localized: "capture.card.weather.rain"),
            detail: "16°C · umbrella weather",
            metadata: "UV 2",
            isSelected: false
        ),
        CaptureCardItem(
            id: "edge-weather-zh-mostly-clear",
            kind: .weather,
            origin: .context,
            title: "大部晴朗无云",
            detail: "21°C · 湿度 48%",
            metadata: "UV 4",
            weatherStyle: .resolve(condition: "大部晴朗无云"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-weather-zh-mostly-cloudy",
            kind: .weather,
            origin: .context,
            title: "大部多云",
            detail: "19°C · 湿度 64%",
            metadata: "UV 2",
            weatherStyle: .resolve(condition: "大部多云"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-weather-zh-thunder-shower",
            kind: .weather,
            origin: .context,
            title: "雷阵雨",
            detail: "17°C · 湿度 86%",
            metadata: "UV 1",
            weatherStyle: .resolve(condition: "雷阵雨"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-weather-zh-wintry-mix",
            kind: .weather,
            origin: .context,
            title: "雨夹雪",
            detail: "1°C · 湿度 82%",
            metadata: "UV 0",
            weatherStyle: .resolve(condition: "雨夹雪"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-weather-zh-haze",
            kind: .weather,
            origin: .context,
            title: "霾",
            detail: "12°C · 湿度 58%",
            metadata: "UV 1",
            weatherStyle: .resolve(condition: "霾"),
            isRemovable: true
        ),
    ]

    static let status: [CaptureCardItem] = [
        CaptureCardItem(
            id: "status-context",
            kind: .status,
            origin: nil,
            state: .loading,
            title: String(localized: "debug.captureCardLab.status.context.title"),
            detail: String(localized: "debug.captureCardLab.status.context.detail")
        ),
        CaptureCardItem(
            id: "status-empty-context",
            kind: .status,
            origin: nil,
            title: String(localized: "debug.captureCardLab.status.emptyContext.title"),
            detail: String(localized: "debug.captureCardLab.status.emptyContext.detail")
        ),
        CaptureCardItem(
            id: "status-photo-processing",
            kind: .status,
            origin: nil,
            state: .loading,
            title: String(localized: "debug.captureCardLab.status.photoProcessing.title"),
            detail: String(localized: "debug.captureCardLab.status.photoProcessing.detail")
        ),
        CaptureCardItem(
            id: "status-voice-refining",
            kind: .status,
            origin: nil,
            state: .loading,
            title: String(localized: "debug.captureCardLab.status.voiceRefining.title"),
            detail: String(localized: "debug.captureCardLab.status.voiceRefining.detail")
        ),
    ]

    static let photoGroups: [CaptureCardItem] = [
        CaptureCardItem(
            id: "photo-single",
            kind: .photo,
            title: String(localized: "debug.captureCardLab.photo.single.title"),
            detail: String(localized: "debug.captureCardLab.photo.single.detail"),
            metadata: String(format: String(localized: "capture.card.photo.count.format"), 1),
            photoCount: 1
        ),
        CaptureCardItem(
            id: "photo-group-mosaic",
            kind: .photo,
            title: String(localized: "debug.captureCardLab.photo.mosaic.title"),
            detail: String(localized: "debug.captureCardLab.photo.mosaic.detail"),
            metadata: String(format: String(localized: "capture.card.photo.count.format"), 4),
            photoCount: 4,
            photoGroupStyle: .mosaic
        ),
        CaptureCardItem(
            id: "photo-group-stack",
            kind: .photo,
            title: String(localized: "debug.captureCardLab.photo.stack.title"),
            detail: String(localized: "debug.captureCardLab.photo.stack.detail"),
            metadata: String(format: String(localized: "capture.card.photo.count.format"), 5),
            photoCount: 5,
            photoGroupStyle: .stack
        ),
        CaptureCardItem(
            id: "photo-group-carousel",
            kind: .photo,
            title: String(localized: "debug.captureCardLab.photo.carousel.title"),
            detail: String(localized: "debug.captureCardLab.photo.carousel.detail"),
            metadata: String(format: String(localized: "capture.card.photo.count.format"), 8),
            photoCount: 8,
            photoGroupStyle: .carousel
        ),
    ]

    static let musicFixtures: [CaptureCardItem] = [
        CaptureCardItem(
            id: "music-fixture-m83",
            kind: .music,
            origin: .context,
            title: "Midnight City",
            detail: "M83 · Hurry Up, We're Dreaming",
            metadata: String(localized: "capture.card.music.nowPlaying"),
            durationSeconds: 244,
            musicPlaybackState: .playing,
            isSelected: true
        ),
        CaptureCardItem(
            id: "music-fixture-japanese-house",
            kind: .music,
            origin: .manual,
            title: "Sunshine Baby",
            detail: "The Japanese House · In the End It Always Does",
            metadata: String(localized: "capture.card.music.searchResult"),
            durationSeconds: 220,
            musicPlaybackState: .searchResult,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "music-fixture-paused",
            kind: .music,
            origin: .context,
            title: String(localized: "debug.captureCardLab.music.paused.title"),
            detail: String(localized: "debug.captureCardLab.music.paused.detail"),
            metadata: String(localized: "capture.card.music.paused"),
            durationSeconds: 184,
            musicPlaybackState: .paused
        ),
    ]

    static let placeScenarios: [CapturePlaceLabScenario] = [
        CapturePlaceLabScenario(
            id: "current-place",
            label: String(localized: "debug.captureCardLab.place.current.label"),
            item: CaptureCardItem(
                id: "place-current",
                kind: .place,
                origin: .context,
                title: String(localized: "debug.captureCardLab.fixture.place.title"),
                detail: String(localized: "debug.captureCardLab.place.current.detail"),
                metadata: "31.218, 121.446",
                latitude: 31.218,
                longitude: 121.446,
                isRemovable: true
            )
        ),
        CapturePlaceLabScenario(
            id: "manual-pin",
            label: String(localized: "debug.captureCardLab.place.manual.label"),
            item: CaptureCardItem(
                id: "place-manual",
                kind: .place,
                origin: .manual,
                title: String(localized: "debug.captureCardLab.place.manual.title"),
                detail: String(localized: "debug.captureCardLab.place.manual.detail"),
                metadata: "31.230, 121.474",
                latitude: 31.230,
                longitude: 121.474,
                isRemovable: true
            )
        ),
        CapturePlaceLabScenario(
            id: "search-result",
            label: String(localized: "capture.card.music.searchResult"),
            item: CaptureCardItem(
                id: "place-search",
                kind: .place,
                origin: .manual,
                title: "Shanghai Library",
                detail: "1555 Huaihai Middle Road",
                metadata: String(localized: "capture.action.search"),
                latitude: 31.207,
                longitude: 121.444,
                isRemovable: true
            )
        ),
        CapturePlaceLabScenario(
            id: "same-name-far",
            label: String(localized: "debug.captureCardLab.place.sameNameFar.label"),
            item: CaptureCardItem(
                id: "place-same-name-far",
                kind: .place,
                origin: .inferred,
                title: "Blue Bottle Coffee",
                detail: String(localized: "debug.captureCardLab.place.sameNameFar.detail"),
                metadata: String(localized: "debug.captureCardLab.place.sameNameFar.metadata"),
                latitude: 37.776,
                longitude: -122.423
            )
        ),
        CapturePlaceLabScenario(
            id: "near-different-name",
            label: String(localized: "debug.captureCardLab.place.nearDifferentName.label"),
            item: CaptureCardItem(
                id: "place-near-different-name",
                kind: .place,
                origin: .context,
                title: String(localized: "debug.captureCardLab.place.nearDifferentName.title"),
                detail: String(localized: "debug.captureCardLab.place.nearDifferentName.detail"),
                metadata: String(localized: "debug.captureCardLab.place.nearDifferentName.metadata"),
                latitude: 31.2184,
                longitude: 121.4463,
                isRemovable: true
            )
        ),
        CapturePlaceLabScenario(
            id: "no-coordinate",
            label: String(localized: "debug.captureCardLab.place.noCoordinate.label"),
            item: CaptureCardItem(
                id: "place-no-coordinate",
                kind: .place,
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
