import Foundation

struct MemoryCaptureArtifactBuilder {
    func buildArtifacts(from draft: MemoryCaptureDraft, recordID: UUID, createdAt: Date) -> [Artifact] {
        let hasTextArtifact = draft.artifacts.contains { artifactDraft in
            if case .text = artifactDraft {
                return true
            }
            return false
        }
        let explicitArtifacts = draft.artifacts.map { artifactDraft in
            makeArtifact(
                from: artifactDraft,
                fallbackTitle: draft.title?.generatedMemoryTitle(),
                suppressAudioTranscriptText: hasTextArtifact,
                recordID: recordID,
                createdAt: createdAt
            )
        }

        if explicitArtifacts.isEmpty {
            return [
                Artifact(
                    recordID: recordID,
                    kind: .text,
                    title: draft.title?.generatedMemoryTitle() ?? draft.rawText.generatedMemoryTitle() ?? "Untitled Memory",
                    summary: draft.rawText.trimmedOrNil ?? "Untitled Memory",
                    textContent: draft.rawText.trimmedOrNil ?? "Untitled Memory",
                    payload: .text(draft.rawText.trimmedOrNil ?? "Untitled Memory"),
                    metadata: [:],
                    createdAt: createdAt,
                    updatedAt: createdAt
                )
            ]
        }

        return explicitArtifacts
    }

    func resolvedRecordRawText(from draft: MemoryCaptureDraft, artifacts: [Artifact]) -> String {
        if let rawText = draft.rawText.trimmedOrNil {
            return rawText
        }

        let artifactSummary = artifacts
            .compactMap { artifact in
                artifact.textContent.trimmedOrNil
                    ?? artifact.summary.trimmedOrNil
                    ?? artifact.title.trimmedOrNil
            }
            .joined(separator: "\n")
            .trimmedOrNil

        return artifactSummary
            ?? draft.artifacts.map(\.captureSummary).joined(separator: "\n").trimmedOrNil
            ?? draft.title?.trimmedOrNil
            ?? "Untitled Memory"
    }

    func preferredPrimaryArtifact(from artifacts: [Artifact]) -> Artifact? {
        artifacts.first(where: { $0.kind == .text && $0.textContent.normalizedNonEmpty != nil })
            ?? artifacts.first(where: { $0.summary.normalizedNonEmpty != nil })
            ?? artifacts.first
    }

    private func makeArtifact(
        from draft: CaptureArtifactDraft,
        fallbackTitle: String?,
        suppressAudioTranscriptText: Bool,
        recordID: UUID,
        createdAt: Date
    ) -> Artifact {
        switch draft {
        case let .text(title, body, _):
            let resolvedBody = body.trimmedOrNil ?? "Untitled Memory"
            return Artifact(
                recordID: recordID,
                kind: .text,
                title: title?.generatedMemoryTitle() ?? fallbackTitle?.trimmedOrNil ?? resolvedBody.generatedMemoryTitle() ?? "Untitled Memory",
                summary: resolvedBody,
                textContent: resolvedBody,
                payload: .text(resolvedBody),
                metadata: metadataForOrigin(of: draft, base: [:]),
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .photo(title, summary, filename, imageData, thumbnailData, ocrText, photoMetadata, _):
            let resolvedSummary = summary.trimmedOrNil ?? "Photo capture"
            var textParts: [String] = []
            if let s = resolvedSummary.trimmedOrNil { textParts.append(s) }
            if let ocr = ocrText.trimmedOrNil { textParts.append("OCR: \(ocr)") }
            let textContent = textParts.isEmpty ? resolvedSummary : textParts.joined(separator: "\n")
            return Artifact(
                recordID: recordID,
                kind: .photo,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Photo",
                summary: resolvedSummary,
                textContent: textContent,
                payload: .media(ArtifactMediaRef(filename: filename, mimeType: "image/jpeg")),
                mediaRef: ArtifactMediaRef(filename: filename, mimeType: "image/jpeg"),
                metadata: metadataForOrigin(of: draft, base: photoMetadata),
                binaryPayload: imageData,
                previewPayload: thumbnailData,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .audio(title, summary, filename, audioData, transcriptionText, _):
            let resolvedSummary = summary.trimmedOrNil ?? "Audio capture"
            let textContent: String
            if suppressAudioTranscriptText {
                textContent = ""
            } else if let transcript = transcriptionText.trimmedOrNil {
                textContent = transcript
            } else {
                textContent = resolvedSummary
            }
            let mimeType = filename.lowercased().hasSuffix(".caf") ? "audio/x-caf" : "audio/m4a"
            var metadata: [String: String] = [:]
            if let transcript = transcriptionText.trimmedOrNil {
                metadata["transcriptionText"] = transcript
            }
            metadata = metadataForOrigin(of: draft, base: metadata)
            return Artifact(
                recordID: recordID,
                kind: .audio,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Audio",
                summary: resolvedSummary,
                textContent: textContent,
                payload: .media(ArtifactMediaRef(filename: filename, mimeType: mimeType)),
                mediaRef: ArtifactMediaRef(filename: filename, mimeType: mimeType),
                metadata: metadata,
                binaryPayload: audioData,
                previewPayload: nil,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .location(title, summary, latitude, longitude, _):
            let resolvedSummary = summary.trimmedOrNil ?? "Location capture"
            var metadata: [String: String] = [:]
            if let latitude { metadata["latitude"] = String(latitude) }
            if let longitude { metadata["longitude"] = String(longitude) }
            metadata = metadataForOrigin(of: draft, base: metadata)
            return Artifact(
                recordID: recordID,
                kind: .location,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Location",
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .metadata(metadata),
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .link(title, url, note, summary, metadata, thumbnailData, _):
            let resolvedSummary = summary?.trimmedOrNil ?? note?.trimmedOrNil ?? url
            let textContent = [summary?.trimmedOrNil, note?.trimmedOrNil]
                .compactMap { $0 }
                .joined(separator: "\n")
                .trimmedOrNil
                ?? resolvedSummary
            var resolvedMetadata = metadata
            resolvedMetadata["url"] = url
            resolvedMetadata = metadataForOrigin(of: draft, base: resolvedMetadata)
            return Artifact(
                recordID: recordID,
                kind: .link,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? url,
                summary: resolvedSummary,
                textContent: textContent,
                payload: .metadata(resolvedMetadata),
                metadata: resolvedMetadata,
                previewPayload: thumbnailData,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .todo(title, note, _):
            let resolvedSummary = note?.trimmedOrNil ?? title
            let metadata = metadataForOrigin(of: draft, base: ["todo": "true"])
            return Artifact(
                recordID: recordID,
                kind: .todo,
                title: title,
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .metadata(metadata),
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .weather(condition, temp, humidity, windSpeed, uvIndex, latitude, longitude, conditionCode, symbolName, isDaylight, _):
            let title = "\(condition) \(String(format: "%.0f", temp))°C"
            let summary = "\(condition) · \(String(format: "%.0f", temp))°C · Humidity \(String(format: "%.0f", humidity * 100))%"
            var metadata: [String: String] = [
                "condition": condition,
                "temperatureCelsius": String(format: "%.1f", temp),
                "humidity": String(format: "%.2f", humidity),
                "windSpeedKmh": String(format: "%.1f", windSpeed),
                "uvIndex": "\(uvIndex)"
            ]
            if let latitude { metadata["latitude"] = String(latitude) }
            if let longitude { metadata["longitude"] = String(longitude) }
            if let conditionCode { metadata["conditionCode"] = conditionCode }
            if let symbolName { metadata["symbolName"] = symbolName }
            if let isDaylight { metadata["isDaylight"] = String(isDaylight) }
            metadata = metadataForOrigin(of: draft, base: metadata)
            return Artifact(
                recordID: recordID,
                kind: .weather,
                title: title,
                summary: summary,
                textContent: summary,
                payload: .metadata(metadata),
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .music(trackName, artistName, albumName, durationSeconds, artworkURL, artworkData, artworkPalette, _):
            let title = "\(trackName) – \(artistName)"
            let summary = [trackName, artistName, albumName].filter { !$0.isEmpty }.joined(separator: " · ")
            var metadata: [String: String] = [
                "trackName": trackName,
                "artistName": artistName,
                "durationSeconds": "\(durationSeconds)"
            ]
            if !albumName.isEmpty { metadata["albumName"] = albumName }
            if let artworkURL { metadata["artworkURL"] = artworkURL }
            if artworkData != nil { metadata["hasArtworkData"] = "true" }
            if let artworkPalette {
                metadata.merge(artworkPalette.metadata) { _, new in new }
            }
            metadata = metadataForOrigin(of: draft, base: metadata)
            return Artifact(
                recordID: recordID,
                kind: .music,
                title: title,
                summary: summary,
                textContent: summary,
                payload: .metadata(metadata),
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        }
    }

    private func metadataForOrigin(of draft: CaptureArtifactDraft, base: [String: String]) -> [String: String] {
        var metadata = base
        metadata["captureOrigin"] = draft.origin.rawValue
        return metadata
    }
}

private extension String {
    var normalizedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
