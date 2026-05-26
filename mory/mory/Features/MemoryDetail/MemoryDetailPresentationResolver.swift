import Foundation

struct MemoryDetailPresentationResolver {
    func resolve(
        snapshot: MemoryDetailSnapshot,
        userPreference: UserSettingsPreference,
        recordPreference: MemoryDetailPresentationPreference?
    ) -> MemoryDetailPresentationSnapshot {
        let bodyText = resolvedBodyText(snapshot)
        let textArtifacts = snapshot.artifacts.filter { $0.kind == .text }
        let contextArtifacts = snapshot.artifacts.filter(isContextArtifact)
        let contextIDs = Set(contextArtifacts.map(\.id))
        let contentArtifacts = snapshot.artifacts
            .filter { !contextIDs.contains($0.id) && $0.kind != .text }
            .sorted { $0.createdAt < $1.createdAt }
        let photoArtifacts = contentArtifacts.filter { $0.kind == .photo || $0.kind == .livePhoto }
        let audioArtifacts = contentArtifacts.filter { $0.kind == .audio }
        let linkArtifacts = contentArtifacts.filter { $0.kind == .link }

        let automaticMode = resolveAutomaticMode(
            record: snapshot.record,
            bodyText: bodyText,
            contentArtifacts: contentArtifacts,
            contextArtifacts: contextArtifacts,
            photoArtifacts: photoArtifacts,
            audioArtifacts: audioArtifacts,
            linkArtifacts: linkArtifacts
        )
        let mode = recordPreference?.mode ?? resolveUserPreferredMode(
            automaticMode: automaticMode,
            userPreference: userPreference
        )

        return MemoryDetailPresentationSnapshot(
            mode: mode,
            record: snapshot.record,
            bodyText: bodyText,
            title: snapshot.record.rawText.generatedMemoryTitle() ?? String(localized: "memory.nav.title"),
            subtitle: snapshot.record.createdAt.formatted(date: .abbreviated, time: .shortened),
            contentArtifacts: contentArtifacts,
            contextArtifacts: contextArtifacts,
            textArtifacts: textArtifacts,
            photoArtifacts: photoArtifacts,
            audioArtifacts: audioArtifacts,
            linkArtifacts: linkArtifacts,
            articleArtifacts: contentArtifacts,
            analysis: snapshot.analysis,
            pipelineStatus: snapshot.pipelineStatus,
            entities: snapshot.entities,
            edges: snapshot.edges,
            arcs: snapshot.arcs,
            reflections: snapshot.reflections
        )
    }

    private func resolveUserPreferredMode(
        automaticMode: MemoryDetailPresentationMode,
        userPreference: UserSettingsPreference
    ) -> MemoryDetailPresentationMode {
        switch userPreference.detailPresentationStrategy {
        case .ruleBased, .aiAutomatic:
            return automaticMode
        case .fixed:
            return userPreference.fixedDetailPresentationMode
        }
    }

    private func resolveAutomaticMode(
        record: RecordShell,
        bodyText: String,
        contentArtifacts: [Artifact],
        contextArtifacts: [Artifact],
        photoArtifacts: [Artifact],
        audioArtifacts: [Artifact],
        linkArtifacts: [Artifact]
    ) -> MemoryDetailPresentationMode {
        let bodyLength = bodyText.trimmingCharacters(in: .whitespacesAndNewlines).count
        let hasArticleBody = bodyLength >= 180 && !isPlaceholderBody(bodyText)
        let nonTextKindCount = Set(contentArtifacts.map(\.kind)).count

        if contentArtifacts.isEmpty {
            if !contextArtifacts.isEmpty && (bodyLength < 90 || isPlaceholderBody(bodyText)) {
                return .checkIn
            }
            return .text
        }

        if photoArtifacts.count >= 2,
           bodyLength < 360,
           audioArtifacts.isEmpty,
           linkArtifacts.isEmpty {
            return .gallery
        }

        if photoArtifacts.count == contentArtifacts.count,
           !photoArtifacts.isEmpty,
           bodyLength < 520 {
            return .gallery
        }

        if audioArtifacts.count == contentArtifacts.count,
           !audioArtifacts.isEmpty,
           photoArtifacts.isEmpty,
           linkArtifacts.isEmpty {
            return .audio
        }

        if linkArtifacts.count == contentArtifacts.count,
           !linkArtifacts.isEmpty,
           photoArtifacts.isEmpty,
           audioArtifacts.isEmpty {
            return .link
        }

        if bodyLength >= 700 && contentArtifacts.count >= 2 {
            return .article
        }

        if hasArticleBody && contentArtifacts.count >= 3 && nonTextKindCount >= 2 {
            return .article
        }

        if audioArtifacts.count >= 1,
           photoArtifacts.isEmpty,
           linkArtifacts.isEmpty,
           bodyLength < 1_200 {
            return .audio
        }

        if linkArtifacts.count >= 1,
           photoArtifacts.isEmpty,
           audioArtifacts.isEmpty,
           bodyLength < 500 {
            return .link
        }

        return .story
    }

    private func resolvedBodyText(_ snapshot: MemoryDetailSnapshot) -> String {
        if let rawText = snapshot.record.rawText.trimmedOrNil {
            return rawText
        }
        return snapshot.artifacts
            .first(where: { $0.kind == .text })?
            .textContent
            .trimmedOrNil
            ?? ""
    }

    private func isContextArtifact(_ artifact: Artifact) -> Bool {
        artifact.metadata["captureOrigin"] == CaptureArtifactOrigin.context.rawValue
    }

    private func isPlaceholderBody(_ body: String) -> Bool {
        let normalized = body
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized == "context check-in"
            || normalized == "audio capture"
            || normalized == "photo capture"
            || normalized == "untitled memory"
    }
}
