import Foundation

struct MemoryCaptureArtifactBuilder {
    func buildArtifacts(from draft: MemoryCaptureDraft, recordID: UUID, createdAt: Date) -> [Artifact] {
        let explicitArtifacts = draft.artifacts.map { artifactDraft in
            makeArtifact(from: artifactDraft, fallbackTitle: draft.title, recordID: recordID, createdAt: createdAt)
        }

        if explicitArtifacts.isEmpty {
            return [
                Artifact(
                    recordID: recordID,
                    kind: .text,
                    title: draft.title?.trimmedOrNil ?? draft.rawText.firstMeaningfulLine ?? "Untitled Memory",
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
        recordID: UUID,
        createdAt: Date
    ) -> Artifact {
        switch draft {
        case let .text(title, body):
            let resolvedBody = body.trimmedOrNil ?? "Untitled Memory"
            return Artifact(
                recordID: recordID,
                kind: .text,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? resolvedBody.firstMeaningfulLine ?? "Untitled Memory",
                summary: resolvedBody,
                textContent: resolvedBody,
                payload: .text(resolvedBody),
                metadata: [:],
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .photo(title, summary, filename, imageData, thumbnailData, ocrText, photoMetadata):
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
                metadata: photoMetadata,
                binaryPayload: imageData,
                previewPayload: thumbnailData,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .audio(title, summary, filename, audioData, transcriptionText):
            let resolvedSummary = summary.trimmedOrNil ?? "Audio capture"
            let textContent: String
            if let transcript = transcriptionText.trimmedOrNil {
                textContent = transcript
            } else {
                textContent = resolvedSummary
            }
            return Artifact(
                recordID: recordID,
                kind: .audio,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Audio",
                summary: resolvedSummary,
                textContent: textContent,
                payload: .media(ArtifactMediaRef(filename: filename, mimeType: "audio/m4a")),
                mediaRef: ArtifactMediaRef(filename: filename, mimeType: "audio/m4a"),
                metadata: [:],
                binaryPayload: audioData,
                previewPayload: nil,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .location(title, summary, latitude, longitude):
            let resolvedSummary = summary.trimmedOrNil ?? "Location capture"
            var metadata: [String: String] = [:]
            if let latitude { metadata["latitude"] = String(latitude) }
            if let longitude { metadata["longitude"] = String(longitude) }
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
        case let .link(title, url, note, summary, metadata, thumbnailData):
            let resolvedSummary = summary?.trimmedOrNil ?? note?.trimmedOrNil ?? url
            let textContent = [summary?.trimmedOrNil, note?.trimmedOrNil]
                .compactMap { $0 }
                .joined(separator: "\n")
                .trimmedOrNil
                ?? resolvedSummary
            var resolvedMetadata = metadata
            resolvedMetadata["url"] = url
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
        case let .todo(title, note):
            let resolvedSummary = note?.trimmedOrNil ?? title
            return Artifact(
                recordID: recordID,
                kind: .todo,
                title: title,
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .metadata(["todo": "true"]),
                metadata: ["todo": "true"],
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .weather(condition, temp, humidity, windSpeed, uvIndex, latitude, longitude):
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
        case let .music(trackName, artistName, albumName, durationSeconds, artworkURL):
            let title = "\(trackName) – \(artistName)"
            let summary = [trackName, artistName, albumName].filter { !$0.isEmpty }.joined(separator: " · ")
            var metadata: [String: String] = [
                "trackName": trackName,
                "artistName": artistName,
                "durationSeconds": "\(durationSeconds)"
            ]
            if !albumName.isEmpty { metadata["albumName"] = albumName }
            if let artworkURL { metadata["artworkURL"] = artworkURL }
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
}

private extension String {
    var normalizedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
