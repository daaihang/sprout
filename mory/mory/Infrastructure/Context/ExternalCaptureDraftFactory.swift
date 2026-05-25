import Foundation

struct ExternalCaptureDraftFactory: Sendable {
    private let attachmentFileStore = ExternalCaptureAttachmentFileStore()
    private let affectMapper = AffectSnapshotMapper()

    func makeDraft(from suggestion: JournalingSuggestionDraft) -> MemoryCaptureDraft {
        var diagnostics = suggestion.bundle.diagnostics
        let importSessionID = UUID()
        let baseProvenance = CaptureProvenance.external(
            sourceKind: .journalingSuggestion,
            importSessionID: importSessionID,
            sourceDisplayName: "Apple Journaling",
            createdAt: suggestion.createdAt
        )
        let bodyText = journalingBodyText(from: suggestion, diagnostics: diagnostics)
        var artifacts: [CaptureArtifactDraft] = [
            .text(title: suggestion.title, body: bodyText, origin: .imported, provenance: baseProvenance)
        ]

        let attachmentsByID = Dictionary(uniqueKeysWithValues: suggestion.bundle.attachments.map { ($0.id, $0) })
        artifacts.append(contentsOf: suggestion.bundle.locations.map { locationDraft(from: $0, provenance: baseProvenance.withJournalingEvidenceID($0.id)) })
        artifacts.append(contentsOf: suggestion.bundle.locationGroups.flatMap { group in
            group.map { locationDraft(from: $0, provenance: baseProvenance.withJournalingEvidenceID($0.id)) }
        })
        artifacts.append(contentsOf: suggestion.bundle.media.map { media in
            mediaDraft(from: media, provenance: baseProvenance.withJournalingEvidenceID(media.id), attachmentsByID: attachmentsByID, diagnostics: &diagnostics)
        })
        artifacts.append(contentsOf: suggestion.bundle.photoVideos.compactMap { media in
            photoVideoDraft(from: media, provenance: baseProvenance.withJournalingEvidenceID(media.id), attachmentsByID: attachmentsByID, diagnostics: &diagnostics)
        })
        artifacts.append(contentsOf: suggestion.bundle.reflections.map { reflection in
            .promptAnswer(prompt: reflection.prompt, answer: nil, source: "Journaling Suggestions", origin: .imported, provenance: baseProvenance.withJournalingEvidenceID(reflection.id))
        })
        artifacts.append(contentsOf: suggestion.bundle.contacts.map { contact in
            let photoData = contact.photoAttachmentID.flatMap { attachmentData(id: $0, attachmentsByID: attachmentsByID, diagnostics: &diagnostics) }
            return .personContext(
                name: contact.name,
                note: "Suggested by Apple Journaling Suggestions",
                photoData: photoData,
                metadata: contact.metadata.merging(["source": "journalSuggestion"]) { _, new in new },
                origin: .imported,
                provenance: baseProvenance.withJournalingEvidenceID(contact.id)
            )
        })

        let affectDrafts = suggestion.bundle.stateOfMind.compactMap {
            makeAffectDraft(from: $0, provenance: baseProvenance.withJournalingEvidenceID($0.id))
        }
        return MemoryCaptureDraft(
            title: suggestion.title,
            rawText: bodyText,
            mood: affectDrafts.first?.rawInput ?? affectDrafts.first?.labels.first?.rawValue,
            inputContext: diagnostics.joined(separator: "\n").trimmedOrNil,
            captureSource: .composer,
            provenance: baseProvenance,
            artifacts: artifacts,
            affectSnapshots: affectDrafts
        )
    }

    func makeDraft(from request: ExternalCaptureRequest) -> MemoryCaptureDraft {
        var diagnostics = request.diagnostics
        if let errorMessage = request.errorMessage?.trimmedOrNil {
            diagnostics.append(errorMessage)
        }

        let importSessionID = UUID()
        let baseProvenance = CaptureProvenance.external(
            sourceKind: request.sourceKind.captureProvenanceSourceKind,
            importSessionID: importSessionID,
            sourceDisplayName: request.sourceKind.displayLabel,
            createdAt: request.receivedAt ?? .now
        )
        let bodyText = bodyText(from: request, diagnostics: diagnostics)
        var artifacts: [CaptureArtifactDraft] = [
            .text(title: request.title, body: bodyText, origin: .imported, provenance: baseProvenance)
        ]

        let evidenceLinkURLs = Set<String>(request.evidenceItems.compactMap { evidence in
            guard evidence.kind == .link else { return nil }
            return evidence.value?.trimmedOrNil ?? evidence.metadata["url"]?.trimmedOrNil
        })
        if let url = request.url?.trimmedOrNil, !evidenceLinkURLs.contains(url) {
            artifacts.append(.link(title: request.title, url: url, note: request.text, origin: .imported, provenance: baseProvenance))
        }

        for evidence in request.evidenceItems {
            artifacts.append(contentsOf: artifactDrafts(from: evidence, request: request, provenance: baseProvenance.withJournalingEvidenceID(evidence.id)))
        }

        for attachment in request.attachments where attachment.role == .primaryMedia || attachment.role == .unknown {
            artifacts.append(attachmentArtifactDraft(from: attachment, request: request, provenance: baseProvenance.withAttachmentRole(attachment.role.rawValue), diagnostics: &diagnostics))
        }

        let affectDrafts = request.affectEvidence.compactMap {
            makeAffectDraft(from: $0, provenance: baseProvenance.withJournalingEvidenceID($0.id))
        }
        return MemoryCaptureDraft(
            title: request.title,
            rawText: bodyText,
            mood: affectDrafts.first?.rawInput ?? affectDrafts.first?.labels.first?.rawValue,
            inputContext: [request.context?.trimmedOrNil, diagnostics.joined(separator: "\n").trimmedOrNil].compactMap { $0 }.joined(separator: "\n").trimmedOrNil,
            captureSource: request.sourceKind == .shareSheet ? .importFile : .composer,
            provenance: baseProvenance,
            artifacts: artifacts,
            affectSnapshots: affectDrafts
        )
    }

    private func journalingBodyText(from suggestion: JournalingSuggestionDraft, diagnostics: [String]) -> String {
        var parts = [suggestion.body?.trimmedOrNil].compactMap { $0 }
        for activity in suggestion.bundle.activities {
            if let summary = activity.summary?.trimmedOrNil, !parts.contains(summary) {
                parts.append(summary)
            }
        }
        for poster in suggestion.bundle.eventPosters {
            let text = [poster.title?.trimmedOrNil, poster.placeName?.trimmedOrNil].compactMap { $0 }.joined(separator: " - ").trimmedOrNil
            if let text, !parts.contains(text) {
                parts.append(text)
            }
        }
        if !diagnostics.isEmpty {
            parts.append("Diagnostics: \(diagnostics.joined(separator: " | "))")
        }
        return parts.joined(separator: "\n").trimmedOrNil ?? "Journaling suggestion"
    }

    private func locationDraft(from location: JournalingLocationEvidence, provenance: CaptureProvenance) -> CaptureArtifactDraft {
        .location(
            title: location.title ?? location.place ?? location.city ?? "Location",
            summary: [location.place, location.city].compactMap { $0?.trimmedOrNil }.joined(separator: ", ").trimmedOrNil ?? "Imported location context",
            latitude: location.latitude,
            longitude: location.longitude,
            origin: .imported,
            provenance: provenance
        )
    }

    private func mediaDraft(
        from media: JournalingMediaEvidence,
        provenance: CaptureProvenance,
        attachmentsByID: [UUID: ExternalCaptureAttachmentDraft],
        diagnostics: inout [String]
    ) -> CaptureArtifactDraft {
        let title = media.title?.trimmedOrNil ?? media.kind.rawValue
        let artist = media.artist?.trimmedOrNil ?? (media.kind == .podcast ? media.albumOrShow?.trimmedOrNil : nil) ?? "Unknown Artist"
        let album = media.albumOrShow?.trimmedOrNil ?? ""
        let artworkData = media.artworkAttachmentID.flatMap { attachmentData(id: $0, attachmentsByID: attachmentsByID, diagnostics: &diagnostics) }
        return .music(
            trackName: title,
            artistName: artist,
            albumName: album,
            durationSeconds: media.metadata["durationSeconds"].flatMap(Int.init) ?? 0,
            artworkURL: nil,
            artworkData: artworkData,
            origin: .imported,
            provenance: provenance
        )
    }

    private func photoVideoDraft(
        from media: JournalingPhotoVideoEvidence,
        provenance: CaptureProvenance,
        attachmentsByID: [UUID: ExternalCaptureAttachmentDraft],
        diagnostics: inout [String]
    ) -> CaptureArtifactDraft? {
        guard let attachmentID = media.attachmentID,
              let attachment = attachmentsByID[attachmentID] else {
            diagnostics.append("Journaling \(media.kind.rawValue) missing attachment.")
            return nil
        }
        switch media.kind {
        case .photo, .livePhotoImage:
            return attachmentArtifactDraft(from: attachment, sourceKind: .journalingSuggestion, title: "Journaling photo", provenance: provenance.withAttachmentRole(attachment.role.rawValue), diagnostics: &diagnostics)
        case .video, .livePhotoVideo:
            return attachmentArtifactDraft(from: attachment, sourceKind: .journalingSuggestion, title: "Journaling video", provenance: provenance.withAttachmentRole(attachment.role.rawValue), diagnostics: &diagnostics)
        }
    }

    private func attachmentData(
        id: UUID,
        attachmentsByID: [UUID: ExternalCaptureAttachmentDraft],
        diagnostics: inout [String]
    ) -> Data? {
        guard let attachment = attachmentsByID[id] else {
            diagnostics.append("Attachment \(id.uuidString) is missing from Journaling bundle.")
            return nil
        }
        return loadAttachmentData(attachment, diagnostics: &diagnostics)
    }

    private func bodyText(from request: ExternalCaptureRequest, diagnostics: [String]) -> String {
        var parts = [request.text.trimmedOrNil].compactMap { $0 }
        for evidence in request.evidenceItems {
            guard evidence.kind == .reflection else { continue }
            let text = [evidence.title, evidence.summary, evidence.value]
                .compactMap { $0?.trimmedOrNil }
                .joined(separator: " - ")
                .trimmedOrNil
            if let text, !parts.contains(text) {
                parts.append(text)
            }
        }
        if !diagnostics.isEmpty {
            parts.append("Diagnostics: \(diagnostics.joined(separator: " | "))")
        }
        return parts.joined(separator: "\n").trimmedOrNil ?? "Shared to Mory."
    }

    private func artifactDrafts(from evidence: ExternalCaptureEvidenceItem, request: ExternalCaptureRequest, provenance: CaptureProvenance) -> [CaptureArtifactDraft] {
        switch evidence.kind {
        case .link:
            guard let url = evidence.value?.trimmedOrNil ?? evidence.metadata["url"]?.trimmedOrNil else { return [] }
            return [.link(title: evidence.title ?? request.title, url: url, note: evidence.summary, origin: .imported, provenance: provenance)]
        case .location:
            let latitude = evidence.metadata["latitude"].flatMap(Double.init)
            let longitude = evidence.metadata["longitude"].flatMap(Double.init)
            return [.location(
                title: evidence.title ?? evidence.value ?? "Location",
                summary: evidence.summary ?? "Imported location context",
                latitude: latitude,
                longitude: longitude,
                origin: .imported,
                provenance: provenance
            )]
        case .song:
            guard let title = evidence.title?.trimmedOrNil ?? evidence.metadata["song"]?.trimmedOrNil else { return [] }
            return [.music(
                trackName: title,
                artistName: evidence.metadata["artist"]?.trimmedOrNil ?? "Unknown Artist",
                albumName: evidence.metadata["album"]?.trimmedOrNil ?? "",
                durationSeconds: 0,
                artworkURL: nil,
                origin: .imported,
                provenance: provenance
            )]
        default:
            return []
        }
    }

    private func attachmentArtifactDraft(
        from attachment: ExternalCaptureAttachmentDraft,
        request: ExternalCaptureRequest,
        provenance: CaptureProvenance,
        diagnostics: inout [String]
    ) -> CaptureArtifactDraft {
        attachmentArtifactDraft(from: attachment, sourceKind: request.sourceKind, title: request.title, provenance: provenance, diagnostics: &diagnostics)
    }

    private func attachmentArtifactDraft(
        from attachment: ExternalCaptureAttachmentDraft,
        sourceKind: ExternalCaptureSourceKind,
        title: String?,
        provenance: CaptureProvenance,
        diagnostics: inout [String]
    ) -> CaptureArtifactDraft {
        let data = loadAttachmentData(attachment, diagnostics: &diagnostics)

        switch attachment.kind {
        case .image:
            return .photo(
                title: title ?? attachment.filename,
                summary: attachment.summary ?? "Imported image from \(sourceKind.rawValue).",
                filename: attachment.filename,
                imageData: data,
                thumbnailData: data,
                ocrText: "",
                photoMetadata: [
                    "source": sourceKind.rawValue,
                    "contentType": attachment.contentType,
                    "storedFileName": attachment.storedFileName ?? "",
                    "attachmentRole": attachment.role.rawValue
                ],
                origin: .imported,
                provenance: provenance
            )
        case .video, .file:
            return .video(
                title: title ?? attachment.filename,
                summary: attachment.summary ?? "Imported video/file from \(sourceKind.rawValue).",
                filename: attachment.filename,
                videoData: data,
                thumbnailData: nil,
                videoMetadata: [
                    "source": sourceKind.rawValue,
                    "contentType": attachment.contentType,
                    "storedFileName": attachment.storedFileName ?? "",
                    "attachmentRole": attachment.role.rawValue
                ],
                origin: .imported,
                provenance: provenance
            )
        }
    }

    private func loadAttachmentData(_ attachment: ExternalCaptureAttachmentDraft, diagnostics: inout [String]) -> Data? {
        let data: Data?
        do {
            data = try attachment.storedFileName.flatMap { try attachmentFileStore.loadData(storedFileName: $0) }
        } catch {
            data = nil
            diagnostics.append("Attachment \(attachment.filename) failed to load: \(error.localizedDescription)")
        }
        if data == nil, attachment.storedFileName != nil {
            diagnostics.append("Attachment \(attachment.filename) is missing from shared storage.")
        }
        for diagnostic in attachment.diagnostics where !diagnostic.isEmpty {
            diagnostics.append("Attachment \(attachment.filename): \(diagnostic)")
        }
        return data
    }

    private func makeAffectDraft(from evidence: ExternalCaptureAffectEvidence, provenance: CaptureProvenance) -> AffectSnapshotDraft? {
        let labels = evidence.labels.isEmpty ? [evidence.label].compactMap { $0 } : evidence.labels
        switch evidence.source {
        case .journalSuggestionStateOfMind, .healthStateOfMind:
            guard let label = labels.first ?? evidence.rawInput?.trimmedOrNil else { return nil }
            var draft = affectMapper.draftFromJournalingStateOfMind(
                label: label,
                allLabels: labels,
                associations: evidence.associations,
                valence: evidence.valence,
                valenceClassification: evidence.valenceClassification,
                kind: evidence.kind
            )
            draft.provenance = provenance
            draft.evidenceMetadata.merge(evidence.metadata) { _, new in new }
            return draft
        case .userSelected:
            var draft = AffectSnapshotDraft(
                labels: labels.compactMap(AffectLabel.init(rawValue:)),
                toneHints: evidence.toneHints.compactMap(ToneHint.init(rawValue:)),
                sources: [.userSelected],
                confidence: evidence.confidence ?? 1,
                evidenceSummary: evidence.rawInput ?? labels.joined(separator: ", "),
                evidenceMetadata: evidence.metadata,
                provenance: provenance,
                userConfirmed: evidence.userConfirmed,
                rawInput: evidence.rawInput ?? labels.first
            )
            draft.valence = evidence.valence
            return draft
        case .fitnessContext:
            guard let rawInput = evidence.rawInput?.trimmedOrNil ?? labels.first else { return nil }
            guard var draft = affectMapper.draft(rawMood: rawInput, source: .healthOrWorkoutContext) else { return nil }
            draft.sources = [.healthOrWorkoutContext]
            draft.valence = evidence.valence ?? draft.valence
            draft.confidence = evidence.confidence ?? draft.confidence
            draft.userConfirmed = evidence.userConfirmed
            draft.evidenceMetadata.merge(evidence.metadata) { _, new in new }
            draft.provenance = provenance
            return draft
        case .unknown:
            return nil
        }
    }
}

private extension ExternalCaptureSourceKind {
    var captureProvenanceSourceKind: CaptureProvenanceSourceKind {
        switch self {
        case .appIntent:
            return .appIntent
        case .shortcut:
            return .shortcut
        case .shareSheet:
            return .shareSheet
        case .journalingSuggestion:
            return .journalingSuggestion
        case .health:
            return .health
        case .fitness:
            return .fitness
        case .unknown:
            return .unknown
        }
    }
}
