import Foundation

struct MemoryCaptureArtifactBuilder {
    func buildArtifacts(from draft: MemoryCaptureDraft, recordID: UUID, createdAt: Date) -> [Artifact] {
        let hasTextArtifact = draft.artifacts.contains { artifactDraft in
            if case .text = artifactDraft.content {
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
                    metadata: draft.provenance.metadata.merging(["captureOrigin": draft.provenance.artifactOrigin.rawValue]) { _, new in new },
                    captureProvenance: draft.provenance,
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
        switch draft.content {
        case let .text(c):
            let resolvedBody = c.body.trimmedOrNil ?? "Untitled Memory"
            return Artifact(
                recordID: recordID,
                kind: .text,
                title: c.title?.generatedMemoryTitle() ?? fallbackTitle?.trimmedOrNil ?? resolvedBody.generatedMemoryTitle() ?? "Untitled Memory",
                summary: resolvedBody,
                textContent: resolvedBody,
                payload: .text(resolvedBody),
                metadata: metadataForOrigin(of: draft, base: [:]),
                captureProvenance: draft.provenance,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .photo(c):
            let resolvedSummary = c.summary.trimmedOrNil ?? "Photo capture"
            var textParts: [String] = []
            if let s = resolvedSummary.trimmedOrNil { textParts.append(s) }
            if let ocr = c.ocrText.trimmedOrNil { textParts.append("OCR: \(ocr)") }
            let textContent = textParts.isEmpty ? resolvedSummary : textParts.joined(separator: "\n")
            return Artifact(
                recordID: recordID,
                kind: .photo,
                title: c.title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Photo",
                summary: resolvedSummary,
                textContent: textContent,
                payload: .media(ArtifactMediaRef(filename: c.filename, mimeType: "image/jpeg")),
                mediaRef: ArtifactMediaRef(filename: c.filename, mimeType: "image/jpeg"),
                metadata: metadataForOrigin(of: draft, base: c.photoMetadata),
                binaryPayload: c.imageData,
                previewPayload: c.thumbnailData,
                captureProvenance: draft.provenance,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .audio(c):
            let resolvedSummary = c.summary.trimmedOrNil ?? "Audio capture"
            let textContent: String
            if suppressAudioTranscriptText {
                textContent = ""
            } else if let transcript = c.transcriptionText.trimmedOrNil {
                textContent = transcript
            } else {
                textContent = resolvedSummary
            }
            let mimeType = c.filename.lowercased().hasSuffix(".caf") ? "audio/x-caf" : "audio/m4a"
            var metadata: [String: String] = [:]
            if let transcript = c.transcriptionText.trimmedOrNil {
                metadata["transcriptionText"] = transcript
            }
            metadata = metadataForOrigin(of: draft, base: metadata)
            return Artifact(
                recordID: recordID,
                kind: .audio,
                title: c.title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Audio",
                summary: resolvedSummary,
                textContent: textContent,
                payload: .media(ArtifactMediaRef(filename: c.filename, mimeType: mimeType)),
                mediaRef: ArtifactMediaRef(filename: c.filename, mimeType: mimeType),
                metadata: metadata,
                binaryPayload: c.audioData,
                previewPayload: nil,
                captureProvenance: draft.provenance,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .video(c):
            let resolvedSummary = c.summary.trimmedOrNil ?? "Video capture"
            let mimeType = c.filename.lowercased().hasSuffix(".mov") ? "video/quicktime" : "video/mp4"
            var metadata = c.videoMetadata
            metadata["filename"] = c.filename
            metadata["mimeType"] = mimeType
            if let byteCount = c.videoData?.count { metadata["byteCount"] = "\(byteCount)" }
            metadata = metadataForOrigin(of: draft, base: metadata)
            return Artifact(
                recordID: recordID,
                kind: .video,
                title: c.title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Video",
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .media(ArtifactMediaRef(filename: c.filename, mimeType: mimeType, byteCount: c.videoData?.count)),
                mediaRef: ArtifactMediaRef(filename: c.filename, mimeType: mimeType, byteCount: c.videoData?.count),
                metadata: metadata,
                binaryPayload: c.videoData,
                previewPayload: c.thumbnailData,
                captureProvenance: draft.provenance,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .livePhoto(c):
            let resolvedSummary = c.summary.trimmedOrNil ?? "Live Photo capture"
            var metadata = c.metadata
            metadata["stillFilename"] = c.stillFilename
            metadata["videoFilename"] = c.videoFilename
            metadata["stillMimeType"] = "image/jpeg"
            metadata["pairedVideoMimeType"] = c.videoFilename.lowercased().hasSuffix(".mov") ? "video/quicktime" : "video/mp4"
            if let byteCount = c.stillImageData?.count { metadata["stillByteCount"] = "\(byteCount)" }
            if let byteCount = c.pairedVideoData?.count { metadata["pairedVideoByteCount"] = "\(byteCount)" }
            metadata = metadataForOrigin(of: draft, base: metadata)
            let mediaRef = ArtifactMediaRef(
                filename: c.stillFilename,
                mimeType: "image/jpeg",
                byteCount: c.stillImageData?.count,
                localIdentifier: metadata["localIdentifier"]
            )
            return Artifact(
                recordID: recordID,
                kind: .livePhoto,
                title: c.title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Live Photo",
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .media(mediaRef),
                mediaRef: mediaRef,
                metadata: metadata,
                binaryPayload: c.pairedVideoData,
                previewPayload: c.thumbnailData ?? c.stillImageData,
                captureProvenance: draft.provenance,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .location(c):
            let resolvedSummary = c.summary.trimmedOrNil ?? "Location capture"
            var metadata: [String: String] = [:]
            if let latitude = c.latitude { metadata["latitude"] = String(latitude) }
            if let longitude = c.longitude { metadata["longitude"] = String(longitude) }
            metadata = metadataForOrigin(of: draft, base: metadata)
            return Artifact(
                recordID: recordID,
                kind: .location,
                title: c.title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Location",
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .metadata(metadata),
                metadata: metadata,
                captureProvenance: draft.provenance,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .link(c):
            let resolvedSummary = c.summary?.trimmedOrNil ?? c.note?.trimmedOrNil ?? c.url
            let textContent = [c.summary?.trimmedOrNil, c.note?.trimmedOrNil]
                .compactMap { $0 }
                .joined(separator: "\n")
                .trimmedOrNil
                ?? resolvedSummary
            var resolvedMetadata = c.metadata
            resolvedMetadata["url"] = c.url
            resolvedMetadata = metadataForOrigin(of: draft, base: resolvedMetadata)
            return Artifact(
                recordID: recordID,
                kind: .link,
                title: c.title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? c.url,
                summary: resolvedSummary,
                textContent: textContent,
                payload: .metadata(resolvedMetadata),
                metadata: resolvedMetadata,
                previewPayload: c.thumbnailData,
                captureProvenance: draft.provenance,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .todo(c):
            let resolvedSummary = c.note?.trimmedOrNil ?? c.title
            let metadata = metadataForOrigin(of: draft, base: ["todo": "true"])
            return Artifact(
                recordID: recordID,
                kind: .todo,
                title: c.title,
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .metadata(metadata),
                metadata: metadata,
                captureProvenance: draft.provenance,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .promptAnswer(c):
            let resolvedAnswer = c.answer?.trimmedOrNil
            let textContent = [
                "Prompt: \(c.prompt)",
                resolvedAnswer.map { "Answer: \($0)" }
            ]
            .compactMap { $0 }
            .joined(separator: "\n")
            let metadata = metadataForOrigin(of: draft, base: [
                "documentType": "promptAnswer",
                "prompt": c.prompt,
                "source": c.source
            ].merging(resolvedAnswer.map { ["answer": $0] } ?? [:]) { _, new in new })
            return Artifact(
                recordID: recordID,
                kind: .document,
                title: c.prompt.generatedMemoryTitle() ?? "Reflection prompt",
                summary: resolvedAnswer ?? c.prompt,
                textContent: textContent,
                payload: .metadata(metadata),
                metadata: metadata,
                captureProvenance: draft.provenance,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .personContext(c):
            let resolvedSummary = c.note?.trimmedOrNil ?? "Person context from capture"
            var resolvedMetadata = c.metadata
            resolvedMetadata["documentType"] = "personContext"
            resolvedMetadata["personName"] = c.name
            resolvedMetadata = metadataForOrigin(of: draft, base: resolvedMetadata)
            return Artifact(
                recordID: recordID,
                kind: .document,
                title: c.name,
                summary: resolvedSummary,
                textContent: [c.name, c.note?.trimmedOrNil].compactMap { $0 }.joined(separator: "\n"),
                payload: .metadata(resolvedMetadata),
                metadata: resolvedMetadata,
                binaryPayload: c.photoData,
                previewPayload: c.photoData,
                captureProvenance: draft.provenance,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .weather(c):
            let title = "\(c.condition) \(String(format: "%.0f", c.temperatureCelsius))°C"
            let summary = "\(c.condition) · \(String(format: "%.0f", c.temperatureCelsius))°C · Humidity \(String(format: "%.0f", c.humidity * 100))%"
            var metadata: [String: String] = [
                "condition": c.condition,
                "temperatureCelsius": String(format: "%.1f", c.temperatureCelsius),
                "humidity": String(format: "%.2f", c.humidity),
                "windSpeedKmh": String(format: "%.1f", c.windSpeedKmh),
                "uvIndex": "\(c.uvIndex)"
            ]
            if let latitude = c.latitude { metadata["latitude"] = String(latitude) }
            if let longitude = c.longitude { metadata["longitude"] = String(longitude) }
            if let conditionCode = c.conditionCode { metadata["conditionCode"] = conditionCode }
            if let symbolName = c.symbolName { metadata["symbolName"] = symbolName }
            if let isDaylight = c.isDaylight { metadata["isDaylight"] = String(isDaylight) }
            metadata = metadataForOrigin(of: draft, base: metadata)
            return Artifact(
                recordID: recordID,
                kind: .weather,
                title: title,
                summary: summary,
                textContent: summary,
                payload: .metadata(metadata),
                metadata: metadata,
                captureProvenance: draft.provenance,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .music(c):
            let title = "\(c.trackName) – \(c.artistName)"
            let summary = [c.trackName, c.artistName, c.albumName].filter { !$0.isEmpty }.joined(separator: " · ")
            var metadata: [String: String] = [
                "trackName": c.trackName,
                "artistName": c.artistName,
                "durationSeconds": "\(c.durationSeconds)"
            ]
            if !c.albumName.isEmpty { metadata["albumName"] = c.albumName }
            if let artworkURL = c.artworkURL { metadata["artworkURL"] = artworkURL }
            if c.artworkData != nil { metadata["hasArtworkData"] = "true" }
            if let artworkPalette = c.artworkPalette {
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
                captureProvenance: draft.provenance,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        }
    }

    private func metadataForOrigin(of draft: CaptureArtifactDraft, base: [String: String]) -> [String: String] {
        var metadata = base
        metadata["captureOrigin"] = draft.origin.rawValue
        if let provenance = draft.provenance {
            metadata.merge(provenance.metadata) { _, new in new }
        }
        return metadata
    }
}

private extension String {
    var normalizedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
