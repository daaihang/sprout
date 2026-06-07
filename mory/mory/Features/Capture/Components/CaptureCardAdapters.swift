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
                provenance: artifact.captureProvenance,
                state: state,
                title: artifact.title.trimmedOrNil ?? String(localized: "capture.card.kind.text"),
                detail: captureCardModelSnippet(artifact.textContent)
                    ?? captureCardModelSnippet(artifact.summary)
                    ?? String(localized: "capture.card.kind.text")
            )
        case .photo:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                payload: .photo(CapturePhotoCardPayload(
                    thumbnailData: artifact.previewPayload ?? artifact.binaryPayload,
                    mediaDimensions: artifact.mediaDimensions
                )),
                origin: artifact.captureCardOrigin,
                provenance: artifact.captureProvenance,
                state: state,
                title: artifact.title.trimmedOrNil,
                detail: captureCardModelSnippet(artifact.summary)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? String(localized: "capture.card.photo.attached"),
                metadata: artifact.mediaRef?.filename.trimmedOrNil,
                isRemovable: false
            )
        case .video:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                payload: .video(CaptureVideoCardPayload(
                    thumbnailData: artifact.previewPayload,
                    durationSeconds: artifact.metadata["durationSeconds"].flatMap(Int.init),
                    mediaDimensions: artifact.mediaDimensions
                )),
                origin: artifact.captureCardOrigin,
                provenance: artifact.captureProvenance,
                state: state,
                title: artifact.title.trimmedOrNil ?? "Video",
                detail: captureCardModelSnippet(artifact.summary)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? artifact.mediaRef?.filename
                    ?? "Video attached",
                metadata: artifact.mediaRef?.filename.trimmedOrNil,
                isRemovable: false
            )
        case .livePhoto:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                payload: .livePhoto(CaptureLivePhotoCardPayload(
                    thumbnailData: artifact.previewPayload,
                    pairedVideoByteCount: artifact.metadata["pairedVideoByteCount"].flatMap(Int.init),
                    mediaDimensions: artifact.mediaDimensions
                )),
                origin: artifact.captureCardOrigin,
                provenance: artifact.captureProvenance,
                state: state,
                title: artifact.title.trimmedOrNil ?? "Live Photo",
                detail: captureCardModelSnippet(artifact.summary)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? artifact.mediaRef?.filename
                    ?? "Live Photo attached",
                metadata: artifact.metadata["videoFilename"]?.trimmedOrNil
                    ?? artifact.mediaRef?.filename.trimmedOrNil,
                isRemovable: false
            )
        case .audio:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                payload: .audio(CaptureAudioCardPayload()),
                origin: artifact.captureCardOrigin,
                provenance: artifact.captureProvenance,
                state: state,
                title: artifact.title.trimmedOrNil ?? String(localized: "capture.card.kind.audio"),
                detail: captureCardModelSnippet(artifact.textContent)
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
                    playbackState: .stopped,
                    catalogID: artifact.metadata["catalogID"]?.trimmedOrNil,
                    storeID: artifact.metadata["storeID"]?.trimmedOrNil
                )),
                origin: artifact.captureCardOrigin,
                provenance: artifact.captureProvenance,
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
                provenance: artifact.captureProvenance,
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
                provenance: artifact.captureProvenance,
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
                provenance: artifact.captureProvenance,
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
                provenance: artifact.captureProvenance,
                state: state,
                title: artifact.title.trimmedOrNil ?? String(localized: "capture.card.kind.todo"),
                detail: captureCardModelSnippet(artifact.summary)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? String(localized: "capture.card.kind.todo"),
                metadata: nil,
                isRemovable: false
            )
        case .document:
            if artifact.metadata["documentType"] == "promptAnswer" {
                let prompt = artifact.metadata["prompt"]?.trimmedOrNil ?? artifact.title
                self.init(
                    id: "artifact-\(artifact.id.uuidString)",
                    payload: .prompt(CapturePromptCardPayload(prompt: prompt, answer: artifact.metadata["answer"]?.trimmedOrNil)),
                    origin: artifact.captureCardOrigin,
                    provenance: artifact.captureProvenance,
                    state: state,
                    title: "Reflection prompt",
                    detail: captureCardModelSnippet(artifact.summary) ?? prompt,
                    metadata: artifact.metadata["source"]?.trimmedOrNil,
                    isRemovable: false
                )
                return
            }
            if artifact.metadata["documentType"] == "personContext" {
                let name = artifact.metadata["personName"]?.trimmedOrNil ?? artifact.title
                self.init(
                    id: "artifact-\(artifact.id.uuidString)",
                    payload: .person(CapturePersonContextCardPayload(name: name, photoData: artifact.previewPayload ?? artifact.binaryPayload)),
                    origin: artifact.captureCardOrigin,
                    provenance: artifact.captureProvenance,
                    state: state,
                    title: name,
                    detail: captureCardModelSnippet(artifact.summary) ?? "Person context",
                    metadata: "Person context",
                    isRemovable: false
                )
                return
            }
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                payload: .status(CaptureStatusCardPayload()),
                origin: artifact.captureCardOrigin,
                provenance: artifact.captureProvenance,
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
        let origin = draft.origin
        let provenance = draft.provenance
        let isRemovable = origin == .manual || origin == .context
        let resolvedID = id ?? "draft-\(draft.id)"

        switch draft.content {
        case let .text(c):
            self.init(
                id: resolvedID,
                payload: .status(CaptureStatusCardPayload()),
                origin: origin,
                provenance: provenance,
                state: state,
                title: c.title ?? String(localized: "capture.card.kind.text"),
                detail: captureCardModelSnippet(c.body) ?? String(localized: "capture.card.kind.text")
            )
        case let .photo(c):
            self.init(
                id: resolvedID,
                payload: .photo(CapturePhotoCardPayload(
                    thumbnailData: c.thumbnailData,
                    mediaDimensions: parseMediaDimensions(from: c.photoMetadata)
                )),
                origin: origin,
                provenance: provenance,
                state: state,
                title: c.title,
                detail: [captureCardModelSnippet(c.summary), captureCardModelSnippet(c.ocrText), c.filename.trimmedOrNil].compactMap { $0 }.first ?? String(localized: "capture.card.photo.attached"),
                metadata: c.filename.trimmedOrNil,
                isRemovable: isRemovable
            )
        case let .audio(c):
            self.init(
                id: resolvedID,
                payload: .audio(CaptureAudioCardPayload()),
                origin: origin,
                provenance: provenance,
                state: state,
                title: c.title ?? String(localized: "capture.card.kind.audio"),
                detail: captureCardModelSnippet(c.transcriptionText) ?? captureCardModelSnippet(c.summary) ?? String(localized: "capture.card.audio.attached"),
                metadata: c.filename.trimmedOrNil,
                isRemovable: isRemovable
            )
        case let .video(c):
            self.init(
                id: resolvedID,
                payload: .video(CaptureVideoCardPayload(
                    thumbnailData: c.thumbnailData,
                    durationSeconds: c.videoMetadata["durationSeconds"].flatMap(Int.init),
                    mediaDimensions: parseMediaDimensions(from: c.videoMetadata)
                )),
                origin: origin,
                provenance: provenance,
                state: state,
                title: c.title ?? "Video",
                detail: captureCardModelSnippet(c.summary) ?? c.filename.trimmedOrNil ?? "Video attached",
                metadata: c.filename.trimmedOrNil,
                isRemovable: isRemovable
            )
        case let .livePhoto(c):
            self.init(
                id: resolvedID,
                payload: .livePhoto(CaptureLivePhotoCardPayload(
                    thumbnailData: c.thumbnailData ?? c.stillImageData,
                    pairedVideoByteCount: c.pairedVideoData?.count,
                    mediaDimensions: parseMediaDimensions(from: c.metadata)
                )),
                origin: origin,
                provenance: provenance,
                state: state,
                title: c.title ?? "Live Photo",
                detail: captureCardModelSnippet(c.summary) ?? c.stillFilename.trimmedOrNil ?? "Live Photo attached",
                metadata: c.videoFilename.trimmedOrNil,
                isRemovable: isRemovable
            )
        case let .location(c):
            self.init(
                id: resolvedID,
                payload: .place(CapturePlaceCardPayload(latitude: c.latitude, longitude: c.longitude)),
                origin: origin,
                provenance: provenance,
                state: state,
                title: c.title ?? String(localized: "capture.card.kind.place"),
                detail: captureCardModelSnippet(c.summary) ?? String(localized: "capture.card.place.attached"),
                metadata: nil,
                isSelected: false,
                isRemovable: isRemovable
            )
        case let .link(c):
            self.init(
                id: resolvedID,
                payload: .link(CaptureLinkCardPayload(thumbnailData: c.thumbnailData)),
                origin: origin,
                provenance: provenance,
                state: state,
                title: c.title ?? String(localized: "capture.card.kind.link"),
                detail: c.summary.flatMap(captureCardModelSnippet) ?? c.note.flatMap(captureCardModelSnippet) ?? captureCardModelSnippet(c.url) ?? String(localized: "capture.card.link.attached"),
                metadata: URL(string: c.url)?.host() ?? c.url,
                isRemovable: isRemovable
            )
        case let .todo(c):
            self.init(
                id: resolvedID,
                payload: .todo(CaptureTodoCardPayload()),
                origin: origin,
                provenance: provenance,
                state: state,
                title: c.title,
                detail: c.note.flatMap(captureCardModelSnippet) ?? String(localized: "capture.card.kind.todo"),
                metadata: String(localized: "capture.card.kind.todo"),
                isRemovable: isRemovable
            )
        case let .promptAnswer(c):
            self.init(
                id: resolvedID,
                payload: .prompt(CapturePromptCardPayload(prompt: c.prompt, answer: c.answer)),
                origin: origin,
                provenance: provenance,
                state: state,
                title: "Reflection prompt",
                detail: c.answer?.trimmedOrNil ?? c.prompt,
                metadata: c.source,
                isRemovable: isRemovable
            )
        case let .personContext(c):
            self.init(
                id: resolvedID,
                payload: .person(CapturePersonContextCardPayload(name: c.name, photoData: c.photoData)),
                origin: origin,
                provenance: provenance,
                state: state,
                title: c.name,
                detail: c.note?.trimmedOrNil ?? "Person context",
                metadata: "Person context",
                isRemovable: isRemovable
            )
        case let .weather(c):
            self.init(
                id: resolvedID,
                payload: .weather(CaptureWeatherCardPayload(
                    latitude: c.latitude,
                    longitude: c.longitude,
                    style: .resolve(
                        conditionCode: c.conditionCode,
                        condition: c.condition,
                        temperatureCelsius: c.temperatureCelsius,
                        windSpeedKmh: c.windSpeedKmh,
                        isDaylight: c.isDaylight
                    ),
                    conditionCode: c.conditionCode,
                    symbolName: c.symbolName,
                    isDaylight: c.isDaylight
                )),
                origin: origin,
                provenance: provenance,
                state: state,
                title: captureWeatherTemperatureTitle(c.temperatureCelsius),
                detail: c.condition,
                metadata: captureWeatherMetadata(humidity: c.humidity, windSpeedKmh: c.windSpeedKmh, uvIndex: c.uvIndex),
                isSelected: false,
                isRemovable: isRemovable
            )
        case let .music(c):
            self.init(
                id: resolvedID,
                payload: .music(CaptureMusicCardPayload(
                    artworkURL: c.artworkURL,
                    artworkData: c.artworkData,
                    artworkPalette: c.artworkPalette,
                    durationSeconds: c.durationSeconds,
                    playbackState: musicPlaybackState,
                    catalogID: c.catalogID?.trimmedOrNil,
                    storeID: c.storeID?.trimmedOrNil
                )),
                origin: origin,
                provenance: provenance,
                state: state,
                title: c.trackName,
                detail: [c.artistName.trimmedOrNil, c.albumName.trimmedOrNil].compactMap { $0 }.joined(separator: " · "),
                metadata: nil,
                isSelected: false,
                isRemovable: isRemovable
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
        captureProvenance?.artifactOrigin ?? metadata["captureOrigin"].flatMap(CaptureArtifactOrigin.init(rawValue:))
    }

    var mediaDimensions: ArtifactMediaDimensions? {
        parseMediaDimensions(from: metadata)
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

private func parseMediaDimensions(from metadata: [String: String]) -> ArtifactMediaDimensions? {
    let dimensions = ArtifactMediaDimensions(
        width: metadata["width"].flatMap(Int.init),
        height: metadata["height"].flatMap(Int.init)
    )
    return dimensions.isEmpty ? nil : dimensions
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
