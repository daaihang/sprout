import Foundation

struct MemoryCaptureArtifactBuildResult: Hashable, Sendable {
    var artifacts: [Artifact]
    var artifactIDByDraftID: [UUID: UUID]
    var semanticDigestHintsByArtifactID: [UUID: ArtifactSemanticDigestHint] = [:]
}

struct ArtifactSemanticDigestHint: Hashable, Sendable {
    var transcript: String?
    var languageCode: String?
    var confidence: Double?
    var durationSeconds: Double?
}

struct MemoryCaptureArtifactBuilder {
    func buildArtifacts(from draft: MemoryCaptureDraft, recordID: UUID, createdAt: Date) -> [Artifact] {
        buildArtifactResult(from: draft, recordID: recordID, createdAt: createdAt).artifacts
    }

    func buildArtifactResult(from draft: MemoryCaptureDraft, recordID: UUID, createdAt: Date) -> MemoryCaptureArtifactBuildResult {
        let explicitPairs = draft.artifacts.map { artifactDraft in
            let artifact = makeArtifact(
                from: artifactDraft,
                fallbackTitle: draft.title?.generatedMemoryTitle(),
                recordID: recordID,
                createdAt: createdAt
            )
            return (artifactDraft.draftID, artifact)
        }
        let explicitArtifacts = explicitPairs.map(\.1)
        let semanticDigestHints = Dictionary(
            uniqueKeysWithValues: zip(draft.artifacts, explicitArtifacts).compactMap { pair in
                let (draft, artifact) = pair
                return semanticDigestHint(from: draft, artifact: artifact).map { (artifact.id, $0) }
            }
        )

        if explicitArtifacts.isEmpty {
            return MemoryCaptureArtifactBuildResult(
                artifacts: [fallbackTextArtifact(from: draft, recordID: recordID, createdAt: createdAt)],
                artifactIDByDraftID: [:]
            )
        }

        return MemoryCaptureArtifactBuildResult(
            artifacts: explicitArtifacts,
            artifactIDByDraftID: Dictionary(uniqueKeysWithValues: explicitPairs.map { ($0.0, $0.1.id) }),
            semanticDigestHintsByArtifactID: semanticDigestHints
        )
    }

    func buildSemanticDigests(from artifacts: [Artifact], createdAt: Date) -> [ArtifactSemanticDigest] {
        artifacts.compactMap { artifact in
            makeSemanticDigest(from: artifact, createdAt: createdAt)
        }
    }

    func buildSemanticDigests(from result: MemoryCaptureArtifactBuildResult, createdAt: Date) -> [ArtifactSemanticDigest] {
        result.artifacts.compactMap { artifact in
            guard var digest = makeSemanticDigest(from: artifact, createdAt: createdAt) else { return nil }
            if let hint = result.semanticDigestHintsByArtifactID[artifact.id] {
                digest.transcript = hint.transcript ?? digest.transcript
                digest.languageCode = hint.languageCode ?? digest.languageCode
                digest.confidence = hint.confidence ?? digest.confidence
                digest.durationSeconds = hint.durationSeconds ?? digest.durationSeconds
            }
            return digest
        }
    }

    func buildCardArrangement(
        from draft: MemoryCaptureDraft,
        record: RecordShell,
        artifacts: [Artifact],
        artifactIDByDraftID: [UUID: UUID],
        createdAt: Date
    ) -> MemoryCardArrangement {
        if let cardArrangement = draft.cardArrangement {
            return cardArrangement.resolve(
                record: record,
                artifacts: artifacts,
                artifactIDByDraftID: artifactIDByDraftID,
                createdAt: createdAt
            )
        }
        return MemoryCardArrangement.defaultArrangement(
            record: record,
            artifacts: artifacts,
            createdAt: createdAt
        )
    }

    func resolvedRecordRawText(from draft: MemoryCaptureDraft, artifacts: [Artifact]) -> String {
        draft.rawText.trimmedOrNil ?? ""
    }

    func preferredPrimaryArtifact(from artifacts: [Artifact]) -> Artifact? {
        artifacts.first(where: { $0.kind == .text && $0.textContent.normalizedNonEmpty != nil })
            ?? artifacts.first(where: { $0.summary.normalizedNonEmpty != nil })
            ?? artifacts.first
    }

    private func fallbackTextArtifact(from draft: MemoryCaptureDraft, recordID: UUID, createdAt: Date) -> Artifact {
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
    }

    private func makeArtifact(
        from draft: CaptureArtifactDraft,
        fallbackTitle: String?,
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
            if let summary = resolvedSummary.trimmedOrNil { textParts.append(summary) }
            if let ocr = c.ocrText.trimmedOrNil { textParts.append("OCR: \(ocr)") }
            let textContent = textParts.isEmpty ? resolvedSummary : textParts.joined(separator: "\n")
            let mediaRef = ArtifactMediaRef(
                filename: c.filename,
                mimeType: "image/jpeg",
                byteCount: c.imageData?.count,
                localIdentifier: c.photoMetadata["localIdentifier"]
            )
            return Artifact(
                recordID: recordID,
                kind: .photo,
                title: c.title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Photo",
                summary: resolvedSummary,
                textContent: textContent,
                payload: .media(mediaRef),
                mediaRef: mediaRef,
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
            if let transcript = c.transcriptionText.trimmedOrNil {
                textContent = transcript
            } else {
                textContent = resolvedSummary
            }
            let mimeType = c.filename.lowercased().hasSuffix(".caf") ? "audio/x-caf" : "audio/m4a"
            var metadata: [String: String] = [:]
            if let durationSeconds = c.durationSeconds {
                metadata["durationSeconds"] = String(durationSeconds)
            }
            metadata = metadataForOrigin(of: draft, base: metadata)
            let mediaRef = ArtifactMediaRef(filename: c.filename, mimeType: mimeType, byteCount: c.audioData?.count)
            return Artifact(
                recordID: recordID,
                kind: .audio,
                title: c.title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Audio",
                summary: resolvedSummary,
                textContent: textContent,
                payload: .media(mediaRef),
                mediaRef: mediaRef,
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
            let mediaRef = ArtifactMediaRef(
                filename: c.filename,
                mimeType: mimeType,
                byteCount: c.videoData?.count,
                localIdentifier: metadata["localIdentifier"]
            )
            return Artifact(
                recordID: recordID,
                kind: .video,
                title: c.title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Video",
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .media(mediaRef),
                mediaRef: mediaRef,
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
            var metadata = c.metadata
            metadata["url"] = c.url
            metadata = metadataForOrigin(of: draft, base: metadata)
            return Artifact(
                recordID: recordID,
                kind: .link,
                title: c.title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? c.url,
                summary: resolvedSummary,
                textContent: textContent,
                payload: .metadata(metadata),
                metadata: metadata,
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
            var metadata = c.metadata
            metadata["documentType"] = "personContext"
            metadata["personName"] = c.name
            metadata = metadataForOrigin(of: draft, base: metadata)
            return Artifact(
                recordID: recordID,
                kind: .document,
                title: c.name,
                summary: resolvedSummary,
                textContent: [c.name, c.note?.trimmedOrNil].compactMap { $0 }.joined(separator: "\n"),
                payload: .metadata(metadata),
                metadata: metadata,
                binaryPayload: c.photoData,
                previewPayload: c.photoData,
                captureProvenance: draft.provenance,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .weather(c):
            let title = "\(c.condition) \(String(format: "%.0f", c.temperatureCelsius))C"
            let summary = "\(c.condition) · \(String(format: "%.0f", c.temperatureCelsius))C · Humidity \(String(format: "%.0f", c.humidity * 100))%"
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
            let title = "\(c.trackName) - \(c.artistName)"
            let summary = [c.trackName, c.artistName, c.albumName].filter { !$0.isEmpty }.joined(separator: " · ")
            var metadata: [String: String] = [
                "trackName": c.trackName,
                "artistName": c.artistName,
                "durationSeconds": "\(c.durationSeconds)"
            ]
            if !c.albumName.isEmpty { metadata["albumName"] = c.albumName }
            if let artworkURL = c.artworkURL { metadata["artworkURL"] = artworkURL }
            if let catalogID = c.catalogID?.trimmedOrNil { metadata["catalogID"] = catalogID }
            if let storeID = c.storeID?.trimmedOrNil { metadata["storeID"] = storeID }
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
                binaryPayload: c.artworkData,
                previewPayload: c.artworkData,
                captureProvenance: draft.provenance,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        }
    }

    private func semanticDigestHint(from draft: CaptureArtifactDraft, artifact: Artifact) -> ArtifactSemanticDigestHint? {
        guard case let .audio(content) = draft.content else { return nil }
        return ArtifactSemanticDigestHint(
            transcript: content.transcriptionText.trimmedOrNil,
            languageCode: content.languageCode?.trimmedOrNil,
            confidence: content.transcriptionConfidence,
            durationSeconds: content.durationSeconds
        )
    }

    private func metadataForOrigin(of draft: CaptureArtifactDraft, base: [String: String]) -> [String: String] {
        var metadata = base
        metadata["captureOrigin"] = draft.origin.rawValue
        if let provenance = draft.provenance {
            metadata.merge(provenance.metadata) { _, new in new }
        }
        return metadata
    }

    private func makeSemanticDigest(from artifact: Artifact, createdAt: Date) -> ArtifactSemanticDigest? {
        switch artifact.kind {
        case .text:
            return nil
        case .photo:
            let parsed = parsePhotoSemanticSummary(artifact.summary)
            return ArtifactSemanticDigest(
                recordID: artifact.recordID,
                artifactID: artifact.id,
                artifactKind: artifact.kind,
                source: .localVision,
                summary: artifact.summary.trimmedOrNil,
                caption: parsed.caption,
                ocrText: parsed.ocrText ?? extractOCRText(from: artifact.textContent),
                visualLabels: parsed.visualLabels,
                dimensions: dimensions(from: artifact.metadata),
                captureDate: artifact.metadata["captureDate"],
                localIdentifier: artifact.mediaRef?.localIdentifier ?? artifact.metadata["localIdentifier"],
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case .video:
            return ArtifactSemanticDigest(
                recordID: artifact.recordID,
                artifactID: artifact.id,
                artifactKind: artifact.kind,
                source: .localMedia,
                summary: artifact.summary.trimmedOrNil,
                caption: artifact.title.trimmedOrNil,
                durationSeconds: artifact.metadata["durationSeconds"].flatMap(Double.init),
                dimensions: dimensions(from: artifact.metadata),
                captureDate: artifact.metadata["captureDate"],
                localIdentifier: artifact.mediaRef?.localIdentifier ?? artifact.metadata["localIdentifier"],
                technicalNotes: compactTechnicalNotes(from: artifact.metadata, keys: ["mimeType", "byteCount", "filename"]),
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case .livePhoto:
            let parsed = parsePhotoSemanticSummary(artifact.summary)
            return ArtifactSemanticDigest(
                recordID: artifact.recordID,
                artifactID: artifact.id,
                artifactKind: artifact.kind,
                source: .localMedia,
                summary: artifact.summary.trimmedOrNil,
                caption: artifact.title.trimmedOrNil ?? parsed.caption,
                ocrText: parsed.ocrText ?? extractOCRText(from: artifact.textContent),
                visualLabels: parsed.visualLabels,
                dimensions: dimensions(from: artifact.metadata),
                captureDate: artifact.metadata["captureDate"],
                localIdentifier: artifact.mediaRef?.localIdentifier ?? artifact.metadata["localIdentifier"],
                technicalNotes: compactTechnicalNotes(
                    from: artifact.metadata,
                    keys: ["stillFilename", "videoFilename", "stillByteCount", "pairedVideoByteCount", "pairedVideoMimeType"]
                ),
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case .audio:
            return ArtifactSemanticDigest(
                recordID: artifact.recordID,
                artifactID: artifact.id,
                artifactKind: artifact.kind,
                source: .localCapture,
                summary: artifact.summary.trimmedOrNil,
                transcript: transcriptCandidate(for: artifact),
                durationSeconds: artifact.metadata["durationSeconds"].flatMap(Double.init),
                localIdentifier: artifact.mediaRef?.localIdentifier ?? artifact.metadata["localIdentifier"],
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case .music, .link, .location, .weather, .todo, .document:
            return ArtifactSemanticDigest(
                recordID: artifact.recordID,
                artifactID: artifact.id,
                artifactKind: artifact.kind,
                source: .localCapture,
                summary: artifact.summary.trimmedOrNil,
                caption: artifact.title.trimmedOrNil,
                durationSeconds: artifact.metadata["durationSeconds"].flatMap(Double.init),
                localIdentifier: artifact.mediaRef?.localIdentifier ?? artifact.metadata["localIdentifier"],
                technicalNotes: digestNotes(for: artifact),
                createdAt: createdAt,
                updatedAt: createdAt
            )
        }
    }

    private func parsePhotoSemanticSummary(_ summary: String) -> (caption: String?, visualLabels: [String], ocrText: String?) {
        let parts = summary
            .components(separatedBy: " | ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let labelPart = parts.first { !$0.hasPrefix("Text:") }
        let labels = labelPart?
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        let ocr = parts.first { $0.hasPrefix("Text:") }?
            .replacingOccurrences(of: "Text:", with: "")
            .trimmedOrNil
        return (labelPart?.trimmedOrNil, labels, ocr)
    }

    private func extractOCRText(from textContent: String) -> String? {
        guard let range = textContent.range(of: "OCR:") else { return nil }
        return String(textContent[range.upperBound...]).trimmedOrNil
    }

    private func dimensions(from metadata: [String: String]) -> ArtifactMediaDimensions? {
        let dimensions = ArtifactMediaDimensions(
            width: metadata["width"].flatMap(Int.init),
            height: metadata["height"].flatMap(Int.init)
        )
        return dimensions.isEmpty ? nil : dimensions
    }

    private func digestNotes(for artifact: Artifact) -> [String] {
        switch artifact.kind {
        case .music:
            return compactTechnicalNotes(from: artifact.metadata, keys: ["trackName", "artistName", "albumName", "durationSeconds"])
        case .link:
            return compactTechnicalNotes(from: artifact.metadata, keys: ["url"])
        case .location:
            return compactTechnicalNotes(from: artifact.metadata, keys: ["latitude", "longitude"])
        case .weather:
            return compactTechnicalNotes(
                from: artifact.metadata,
                keys: ["condition", "temperatureCelsius", "humidity", "windSpeedKmh", "uvIndex", "conditionCode", "symbolName"]
            )
        case .document:
            return compactTechnicalNotes(from: artifact.metadata, keys: ["documentType", "personName", "source"])
        case .todo:
            return compactTechnicalNotes(from: artifact.metadata, keys: ["todo"])
        case .text, .photo, .audio, .video, .livePhoto:
            return []
        }
    }

    private func transcriptCandidate(for artifact: Artifact) -> String? {
        guard artifact.kind == .audio, let text = artifact.textContent.trimmedOrNil else { return nil }
        return text == artifact.summary.trimmedOrNil ? nil : text
    }

    private func compactTechnicalNotes(from metadata: [String: String], keys: [String]) -> [String] {
        keys.compactMap { key in
            metadata[key].flatMap { value in
                value.trimmedOrNil.map { "\(key)=\($0)" }
            }
        }
    }
}

private extension String {
    var normalizedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
