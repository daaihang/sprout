import Foundation

struct ExternalCaptureInboxCodec: Sendable {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func makeItem(from request: ExternalCaptureRequest, now: Date = .now) throws -> ExternalCaptureInboxItem {
        var normalized = request
        normalized.version = ExternalCaptureRequest.currentVersion
        normalized.receivedAt = request.receivedAt ?? now
        let data = try encoder.encode(normalized)
        return ExternalCaptureInboxItem(
            payloadKind: .externalCapture,
            sourceKind: normalized.sourceKind,
            title: normalized.title?.trimmedOrNil,
            summary: summary(
                from: [normalized.text, normalized.url, normalized.attachments.first?.summary]
                    .compactMap { $0?.trimmedOrNil }
                    .joined(separator: " "),
                fallback: normalized.url ?? normalized.sourceKind.rawValue
            ),
            payloadData: data,
            receivedAt: now,
            updatedAt: now,
            errorMessage: normalized.errorMessage?.trimmedOrNil ?? normalized.diagnostics.joined(separator: "\n").trimmedOrNil
        )
    }

    func makeItem(from suggestion: JournalingSuggestionDraft, now: Date = .now) throws -> ExternalCaptureInboxItem {
        var normalized = suggestion
        normalized.version = JournalingSuggestionDraft.currentVersion
        let data = try encoder.encode(normalized)
        return ExternalCaptureInboxItem(
            payloadKind: .journalingSuggestion,
            sourceKind: .journalingSuggestion,
            title: normalized.title?.trimmedOrNil,
            summary: summary(
                from: [normalized.body, normalized.evidenceItems.first?.title, normalized.evidenceItems.first?.summary]
                    .compactMap { $0?.trimmedOrNil }
                    .joined(separator: " "),
                fallback: "Journaling suggestion"
            ),
            payloadData: data,
            receivedAt: now,
            updatedAt: now,
            errorMessage: normalized.diagnostics.joined(separator: "\n").trimmedOrNil
        )
    }

    func makeDraft(from item: ExternalCaptureInboxItem) throws -> MemoryCaptureDraft {
        switch item.payloadKind {
        case .externalCapture:
            let request = try decoder.decode(ExternalCaptureRequest.self, from: item.payloadData)
            return ExternalCaptureDraftFactory().makeDraft(from: request).withExternalInboxItemID(item.id)
        case .journalingSuggestion:
            let suggestion = try decoder.decode(JournalingSuggestionDraft.self, from: item.payloadData)
            return JournalingSuggestionContextService().makeCaptureDraft(from: suggestion).withExternalInboxItemID(item.id)
        }
    }

    private func summary(from text: String, fallback: String) -> String {
        let value = text.trimmedOrNil ?? fallback
        let maxLength = 160
        guard value.count > maxLength else { return value }
        return String(value.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
