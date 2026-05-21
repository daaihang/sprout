import Foundation

extension CaptureCardItem {
    init(attachment item: CaptureComposerAttachmentItem) {
        self = item.card
    }

    init(artifact: Artifact, state: CaptureCardState = .normal) {
        switch artifact.kind {
        case .text:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                payload: .status(CaptureStatusCardPayload()),
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.title.trimmedOrNil ?? String(localized: "capture.card.kind.text"),
                detail: captureCardModelSnippet(artifact.textContent)
                    ?? captureCardModelSnippet(artifact.summary)
                    ?? String(localized: "capture.card.kind.text")
            )
        case .photo:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                payload: .photo(CapturePhotoCardPayload(thumbnailData: artifact.previewPayload ?? artifact.binaryPayload)),
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.title.trimmedOrNil,
                detail: captureCardModelSnippet(artifact.summary)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? String(localized: "capture.card.photo.attached"),
                metadata: artifact.mediaRef?.filename.trimmedOrNil,
                isRemovable: false
            )
        case .audio:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                payload: .audio(CaptureAudioCardPayload()),
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.title.trimmedOrNil ?? String(localized: "capture.card.kind.audio"),
                detail: artifact.metadata["transcriptionText"].flatMap(captureCardModelSnippet)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? captureCardModelSnippet(artifact.summary)
                    ?? String(localized: "capture.card.audio.attached"),
                metadata: artifact.mediaRef?.filename.trimmedOrNil,
                isRemovable: false
            )
        case .music:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                payload: .music(CaptureMusicCardPayload(
                    artworkURL: artifact.metadata["artworkURL"]?.trimmedOrNil,
                    artworkData: artifact.previewPayload ?? artifact.binaryPayload,
                    artworkPalette: artifact.captureCardArtworkPalette,
                    durationSeconds: artifact.metadata["durationSeconds"].flatMap(Int.init),
                    playbackState: .stopped
                )),
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.metadata["trackName"]?.trimmedOrNil
                    ?? artifact.title.trimmedOrNil
                    ?? String(localized: "capture.card.kind.music"),
                detail: [
                    artifact.metadata["artistName"]?.trimmedOrNil,
                    artifact.metadata["albumName"]?.trimmedOrNil
                ]
                .compactMap { $0 }
                .joined(separator: " · ")
                .trimmedOrNil
                    ?? captureCardModelSnippet(artifact.summary)
                    ?? String(localized: "capture.card.kind.music"),
                metadata: nil,
                isRemovable: false
            )
        case .link:
            let url = artifact.metadata["url"]?.trimmedOrNil
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                payload: .link(CaptureLinkCardPayload(thumbnailData: artifact.previewPayload)),
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.title.trimmedOrNil ?? String(localized: "capture.card.kind.link"),
                detail: captureCardModelSnippet(artifact.summary)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? url
                    ?? String(localized: "capture.card.link.attached"),
                metadata: url.flatMap { URL(string: $0)?.host() },
                isRemovable: false
            )
        case .location:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                payload: .place(CapturePlaceCardPayload(
                    latitude: artifact.metadata["latitude"].flatMap(Double.init),
                    longitude: artifact.metadata["longitude"].flatMap(Double.init)
                )),
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.title.trimmedOrNil ?? String(localized: "capture.card.kind.place"),
                detail: captureCardModelSnippet(artifact.summary)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? String(localized: "capture.card.place.attached"),
                metadata: nil,
                isRemovable: false
            )
        case .weather:
            let condition = artifact.metadata["condition"]?.trimmedOrNil
                ?? artifact.summary.trimmedOrNil
                ?? artifact.title.trimmedOrNil
                ?? String(localized: "capture.card.kind.weather")
            let temperature = artifact.metadata["temperatureCelsius"].flatMap(Double.init)
            let windSpeed = artifact.metadata["windSpeedKmh"].flatMap(Double.init)
            let humidity = artifact.metadata["humidity"].flatMap(Double.init)
            let uvIndex = artifact.metadata["uvIndex"].flatMap(Int.init)
            let isDaylight = artifact.metadata["isDaylight"].flatMap(Bool.init)
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                payload: .weather(CaptureWeatherCardPayload(
                    latitude: artifact.metadata["latitude"].flatMap(Double.init),
                    longitude: artifact.metadata["longitude"].flatMap(Double.init),
                    style: .resolve(
                        conditionCode: artifact.metadata["conditionCode"],
                        condition: condition,
                        temperatureCelsius: temperature,
                        windSpeedKmh: windSpeed,
                        isDaylight: isDaylight
                    ),
                    conditionCode: artifact.metadata["conditionCode"]?.trimmedOrNil,
                    symbolName: artifact.metadata["symbolName"]?.trimmedOrNil,
                    isDaylight: isDaylight
                )),
                origin: artifact.captureCardOrigin,
                state: state,
                title: temperature.map(captureWeatherTemperatureTitle) ?? artifact.title.trimmedOrNil,
                detail: condition,
                metadata: Self.weatherMetadata(humidity: humidity, windSpeedKmh: windSpeed, uvIndex: uvIndex),
                isRemovable: false
            )
        case .todo:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                payload: .todo(CaptureTodoCardPayload()),
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.title.trimmedOrNil ?? String(localized: "capture.card.kind.todo"),
                detail: captureCardModelSnippet(artifact.summary)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? String(localized: "capture.card.kind.todo"),
                metadata: nil,
                isRemovable: false
            )
        case .document:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                payload: .status(CaptureStatusCardPayload()),
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.title.trimmedOrNil ?? String(localized: "capture.card.kind.status"),
                detail: captureCardModelSnippet(artifact.summary)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? artifact.mediaRef?.filename
                    ?? String(localized: "capture.card.kind.status"),
                metadata: artifact.mediaRef?.filename.trimmedOrNil,
                isRemovable: false
            )
        }
    }

    init(
        draft: CaptureArtifactDraft,
        id: String? = nil,
        state: CaptureCardState = .normal,
        musicPlaybackState: CaptureMusicPlaybackState? = nil
    ) {
        switch draft {
        case let .text(title, body, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                payload: .status(CaptureStatusCardPayload()),
                origin: origin,
                state: state,
                title: title ?? String(localized: "capture.card.kind.text"),
                detail: captureCardModelSnippet(body) ?? String(localized: "capture.card.kind.text")
            )
        case let .photo(title, summary, filename, _, thumbnailData, ocrText, _, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                payload: .photo(CapturePhotoCardPayload(thumbnailData: thumbnailData)),
                origin: origin,
                state: state,
                title: title,
                detail: [captureCardModelSnippet(summary), captureCardModelSnippet(ocrText), filename.trimmedOrNil].compactMap { $0 }.first ?? String(localized: "capture.card.photo.attached"),
                metadata: filename.trimmedOrNil,
                isRemovable: origin == .manual || origin == .context
            )
        case let .audio(title, summary, filename, _, transcriptionText, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                payload: .audio(CaptureAudioCardPayload()),
                origin: origin,
                state: state,
                title: title ?? String(localized: "capture.card.kind.audio"),
                detail: captureCardModelSnippet(transcriptionText) ?? captureCardModelSnippet(summary) ?? String(localized: "capture.card.audio.attached"),
                metadata: filename.trimmedOrNil,
                isRemovable: origin == .manual || origin == .context
            )
        case let .location(title, summary, latitude, longitude, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                payload: .place(CapturePlaceCardPayload(latitude: latitude, longitude: longitude)),
                origin: origin,
                state: state,
                title: title ?? String(localized: "capture.card.kind.place"),
                detail: captureCardModelSnippet(summary) ?? String(localized: "capture.card.place.attached"),
                metadata: nil,
                isSelected: false,
                isRemovable: origin == .manual || origin == .context
            )
        case let .link(title, url, note, summary, _, thumbnailData, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                payload: .link(CaptureLinkCardPayload(thumbnailData: thumbnailData)),
                origin: origin,
                state: state,
                title: title ?? String(localized: "capture.card.kind.link"),
                detail: summary.flatMap(captureCardModelSnippet) ?? note.flatMap(captureCardModelSnippet) ?? captureCardModelSnippet(url) ?? String(localized: "capture.card.link.attached"),
                metadata: URL(string: url)?.host() ?? url,
                isRemovable: origin == .manual || origin == .context
            )
        case let .todo(title, note, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                payload: .todo(CaptureTodoCardPayload()),
                origin: origin,
                state: state,
                title: title,
                detail: note.flatMap(captureCardModelSnippet) ?? String(localized: "capture.card.kind.todo"),
                metadata: String(localized: "capture.card.kind.todo"),
                isRemovable: origin == .manual || origin == .context
            )
        case let .weather(condition, temp, humidity, windSpeed, uvIndex, latitude, longitude, conditionCode, symbolName, isDaylight, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                payload: .weather(CaptureWeatherCardPayload(
                    latitude: latitude,
                    longitude: longitude,
                    style: .resolve(
                        conditionCode: conditionCode,
                        condition: condition,
                        temperatureCelsius: temp,
                        windSpeedKmh: windSpeed,
                        isDaylight: isDaylight
                    ),
                    conditionCode: conditionCode,
                    symbolName: symbolName,
                    isDaylight: isDaylight
                )),
                origin: origin,
                state: state,
                title: captureWeatherTemperatureTitle(temp),
                detail: condition,
                metadata: captureWeatherMetadata(humidity: humidity, windSpeedKmh: windSpeed, uvIndex: uvIndex),
                isSelected: false,
                isRemovable: origin == .manual || origin == .context
            )
        case let .music(trackName, artistName, albumName, durationSeconds, artworkURL, artworkData, artworkPalette, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                payload: .music(CaptureMusicCardPayload(
                    artworkURL: artworkURL,
                    artworkData: artworkData,
                    artworkPalette: artworkPalette,
                    durationSeconds: durationSeconds,
                    playbackState: musicPlaybackState
                )),
                origin: origin,
                state: state,
                title: trackName,
                detail: [artistName.trimmedOrNil, albumName.trimmedOrNil].compactMap { $0 }.joined(separator: " · "),
                metadata: nil,
                isSelected: false,
                isRemovable: origin == .manual || origin == .context
            )
        }
    }

    private static func weatherMetadata(humidity: Double?, windSpeedKmh: Double?, uvIndex: Int?) -> String? {
        guard let humidity, let windSpeedKmh, let uvIndex else { return nil }
        return captureWeatherMetadata(humidity: humidity, windSpeedKmh: windSpeedKmh, uvIndex: uvIndex)
    }
}

private extension Artifact {
    var captureCardOrigin: CaptureArtifactOrigin? {
        metadata["captureOrigin"].flatMap(CaptureArtifactOrigin.init(rawValue:))
    }

    var captureCardArtworkPalette: MusicArtworkPalette? {
        let palette = MusicArtworkPalette(
            backgroundColorHex: metadata["artworkBackgroundColor"]?.trimmedOrNil,
            primaryTextColorHex: metadata["artworkPrimaryTextColor"]?.trimmedOrNil,
            secondaryTextColorHex: metadata["artworkSecondaryTextColor"]?.trimmedOrNil
        )
        return palette.isEmpty ? nil : palette
    }
}

nonisolated func captureCardModelSnippet(_ value: String?) -> String? {
    let value = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !value.isEmpty else { return nil }
    let collapsed = value
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    guard collapsed.count > 96 else { return collapsed }
    return String(collapsed.prefix(93)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
}
