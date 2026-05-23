import Foundation

struct ExternalCaptureDraftFactory: Sendable {
    private let attachmentFileStore = ExternalCaptureAttachmentFileStore()
    private let affectMapper = AffectSnapshotMapper()

    func makeDraft(from request: ExternalCaptureRequest) -> MemoryCaptureDraft {
        var diagnostics = request.diagnostics
        if let errorMessage = request.errorMessage?.trimmedOrNil {
            diagnostics.append(errorMessage)
        }

        let bodyText = bodyText(from: request, diagnostics: diagnostics)
        var artifacts: [CaptureArtifactDraft] = [
            .text(title: request.title, body: bodyText, origin: .imported)
        ]

        let evidenceLinkURLs = Set<String>(request.evidenceItems.compactMap { evidence in
            guard evidence.kind == .link else { return nil }
            return evidence.value?.trimmedOrNil ?? evidence.metadata["url"]?.trimmedOrNil
        })
        if let url = request.url?.trimmedOrNil, !evidenceLinkURLs.contains(url) {
            artifacts.append(.link(title: request.title, url: url, note: request.text, origin: .imported))
        }

        for evidence in request.evidenceItems {
            artifacts.append(contentsOf: artifactDrafts(from: evidence, request: request))
        }

        for attachment in request.attachments {
            artifacts.append(attachmentArtifactDraft(from: attachment, request: request, diagnostics: &diagnostics))
        }

        let affectDrafts = request.affectEvidence.compactMap(makeAffectDraft)
        return MemoryCaptureDraft(
            title: request.title,
            rawText: bodyText,
            mood: affectDrafts.first?.rawInput ?? affectDrafts.first?.labels.first?.rawValue,
            inputContext: inputContext(from: request, diagnostics: diagnostics),
            captureSource: request.sourceKind == .shareSheet ? .importFile : .composer,
            artifacts: artifacts,
            affectSnapshots: affectDrafts
        )
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

    private func inputContext(from request: ExternalCaptureRequest, diagnostics: [String]) -> String {
        var parts = [
            request.context?.trimmedOrNil,
            "externalCapture:v\(request.version)",
            "source=\(request.sourceKind.rawValue)"
        ]
        if !diagnostics.isEmpty {
            parts.append("diagnostics=\(diagnostics.joined(separator: " | "))")
        }
        return parts.compactMap { $0 }.joined(separator: "\n")
    }

    private func artifactDrafts(from evidence: ExternalCaptureEvidenceItem, request: ExternalCaptureRequest) -> [CaptureArtifactDraft] {
        switch evidence.kind {
        case .link:
            guard let url = evidence.value?.trimmedOrNil ?? evidence.metadata["url"]?.trimmedOrNil else { return [] }
            return [.link(title: evidence.title ?? request.title, url: url, note: evidence.summary, origin: .imported)]
        case .location:
            let latitude = evidence.metadata["latitude"].flatMap(Double.init)
            let longitude = evidence.metadata["longitude"].flatMap(Double.init)
            return [.location(
                title: evidence.title ?? evidence.value ?? "Location",
                summary: evidence.summary ?? "Imported location context",
                latitude: latitude,
                longitude: longitude,
                origin: .imported
            )]
        case .song:
            guard let title = evidence.title?.trimmedOrNil ?? evidence.metadata["song"]?.trimmedOrNil else { return [] }
            return [.music(
                trackName: title,
                artistName: evidence.metadata["artist"]?.trimmedOrNil ?? "Unknown Artist",
                albumName: evidence.metadata["album"]?.trimmedOrNil ?? "",
                durationSeconds: 0,
                artworkURL: nil,
                origin: .imported
            )]
        default:
            return []
        }
    }

    private func attachmentArtifactDraft(
        from attachment: ExternalCaptureAttachmentDraft,
        request: ExternalCaptureRequest,
        diagnostics: inout [String]
    ) -> CaptureArtifactDraft {
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

        switch attachment.kind {
        case .image:
            return .photo(
                title: request.title ?? attachment.filename,
                summary: attachment.summary ?? "Imported image from \(request.sourceKind.rawValue).",
                filename: attachment.filename,
                imageData: data,
                thumbnailData: data,
                ocrText: "",
                photoMetadata: [
                    "source": request.sourceKind.rawValue,
                    "contentType": attachment.contentType,
                    "storedFileName": attachment.storedFileName ?? ""
                ],
                origin: .imported
            )
        case .video, .file:
            return .video(
                title: request.title ?? attachment.filename,
                summary: attachment.summary ?? "Imported video/file from \(request.sourceKind.rawValue).",
                filename: attachment.filename,
                videoData: data,
                thumbnailData: nil,
                videoMetadata: [
                    "source": request.sourceKind.rawValue,
                    "contentType": attachment.contentType,
                    "storedFileName": attachment.storedFileName ?? ""
                ],
                origin: .imported
            )
        }
    }

    private func makeAffectDraft(from evidence: ExternalCaptureAffectEvidence) -> AffectSnapshotDraft? {
        let labels = evidence.labels.isEmpty ? [evidence.label].compactMap { $0 } : evidence.labels
        switch evidence.source {
        case .journalSuggestionStateOfMind, .healthStateOfMind:
            guard let label = labels.first ?? evidence.rawInput?.trimmedOrNil else { return nil }
            return affectMapper.draftFromJournalingStateOfMind(
                label: label,
                allLabels: labels,
                associations: evidence.associations,
                valence: evidence.valence,
                valenceClassification: evidence.valenceClassification,
                kind: evidence.kind
            )
        case .userSelected:
            var draft = AffectSnapshotDraft(
                labels: labels.compactMap(AffectLabel.init(rawValue:)),
                toneHints: evidence.toneHints.compactMap(ToneHint.init(rawValue:)),
                sources: [.userSelected],
                confidence: evidence.confidence ?? 1,
                evidenceSummary: evidence.rawInput ?? labels.joined(separator: ", "),
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
            return draft
        case .unknown:
            return nil
        }
    }
}
