import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

struct SpotlightSearchableItemBuilder {
    let ownerID: String?

    init(ownerID: String? = nil) {
        self.ownerID = ownerID?.trimmedOrNil
    }

    var memoryDomain: String {
        SpotlightSearchableItemIdentifier.memoryDomain(ownerID: ownerID)
    }

    func memoryIdentifier(_ id: UUID) -> String {
        SpotlightSearchableItemIdentifier.memory(id, ownerID: ownerID)
    }

    func makeMemoryItem(
        memory: MemorySummary,
        artifacts: [Artifact],
        analysis: RecordAnalysisSnapshot?
    ) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = memory.title
        attributes.displayName = memory.title
        attributes.contentDescription = memory.summaryText
        attributes.textContent = canonicalMemoryText(memory: memory, artifacts: artifacts, analysis: analysis)
        attributes.keywords = keywords(memory: memory, artifacts: artifacts, analysis: analysis)
        attributes.contentCreationDate = memory.record.createdAt
        attributes.metadataModificationDate = memory.record.updatedAt
        attributes.userCreated = true
        attributes.userOwned = true
        if let salienceScore = analysis?.salienceScore {
            attributes.rankingHint = NSNumber(value: min(max(salienceScore, 0), 1) * 100)
        }

        if let audioTranscript = artifacts.first(where: { $0.kind == .audio })?.textContent.trimmedOrNil {
            if #available(iOS 18.4, *) {
                attributes.transcribedTextContent = audioTranscript
            }
        }

        if let location = artifacts.first(where: { $0.kind == .location || $0.kind == .weather }) {
            attributes.namedLocation = location.title.trimmedOrNil ?? location.summary.trimmedOrNil
            if let latitude = location.metadata["latitude"].flatMap(Double.init) {
                attributes.latitude = NSNumber(value: latitude)
            }
            if let longitude = location.metadata["longitude"].flatMap(Double.init) {
                attributes.longitude = NSNumber(value: longitude)
            }
        }

        let item = CSSearchableItem(
            uniqueIdentifier: memoryIdentifier(memory.id),
            domainIdentifier: memoryDomain,
            attributeSet: attributes
        )
        item.expirationDate = .distantFuture
        return item
    }

    private func canonicalMemoryText(
        memory: MemorySummary,
        artifacts: [Artifact],
        analysis: RecordAnalysisSnapshot?
    ) -> String {
        var parts = [
            memory.title,
            memory.summaryText,
            memory.record.rawText,
            memory.record.userMood,
            memory.record.inputContext,
            analysis?.summary,
            analysis?.emotionInterpretation,
            analysis?.reflectionHint
        ].compactMap { $0?.trimmedOrNil }

        parts.append(contentsOf: analysis?.themes ?? [])
        parts.append(contentsOf: analysis?.retrievalTerms ?? [])
        parts.append(contentsOf: analysis?.entityMentions.flatMap { mention in
            [mention.name] + mention.aliases
        } ?? [])

        for artifact in artifacts {
            parts.append(contentsOf: [
                artifact.kind.rawValue,
                artifact.title,
                artifact.summary,
                artifact.textContent
            ].compactMap(\.trimmedOrNil))
        }

        return unique(parts).joined(separator: "\n")
    }

    private func keywords(
        memory: MemorySummary,
        artifacts: [Artifact],
        analysis: RecordAnalysisSnapshot?
    ) -> [String] {
        var values = [
            memory.record.captureSource.rawValue,
            memory.record.userMood
        ].compactMap { $0?.trimmedOrNil }

        values.append(contentsOf: artifacts.map { $0.kind.rawValue })
        values.append(contentsOf: artifacts.flatMap { artifact in
            [artifact.title, artifact.summary].compactMap(\.trimmedOrNil)
        })
        values.append(contentsOf: analysis?.themes ?? [])
        values.append(contentsOf: analysis?.retrievalTerms ?? [])
        values.append(contentsOf: analysis?.entityMentions.flatMap { mention in
            [mention.name] + mention.aliases
        } ?? [])

        return unique(values)
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            guard let normalized = value.trimmedOrNil else { continue }
            let key = normalized.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(normalized)
        }
        return result
    }
}
