import Foundation

struct ExternalCaptureRequest: Codable, Hashable, Sendable {
    static let currentVersion = 2

    var version: Int
    var sourceKind: ExternalCaptureSourceKind
    var receivedAt: Date?
    var title: String?
    var text: String
    var url: String?
    var context: String?
    var errorMessage: String?
    var evidenceItems: [ExternalCaptureEvidenceItem]
    var affectEvidence: [ExternalCaptureAffectEvidence]
    var attachments: [ExternalCaptureAttachmentDraft]
    var diagnostics: [String]

    init(
        version: Int = Self.currentVersion,
        sourceKind: ExternalCaptureSourceKind,
        receivedAt: Date? = nil,
        title: String? = nil,
        text: String,
        url: String? = nil,
        context: String? = nil,
        errorMessage: String? = nil,
        evidenceItems: [ExternalCaptureEvidenceItem] = [],
        affectEvidence: [ExternalCaptureAffectEvidence] = [],
        attachments: [ExternalCaptureAttachmentDraft] = [],
        diagnostics: [String] = []
    ) {
        self.version = version
        self.sourceKind = sourceKind
        self.receivedAt = receivedAt
        self.title = title
        self.text = text
        self.url = url
        self.context = context
        self.errorMessage = errorMessage
        self.evidenceItems = evidenceItems
        self.affectEvidence = affectEvidence
        self.attachments = attachments
        self.diagnostics = diagnostics
    }

    private enum CodingKeys: String, CodingKey {
        case version, sourceKind, receivedAt, title, text, url, context, errorMessage
        case evidenceItems, affectEvidence, attachments, diagnostics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        guard version == Self.currentVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .version,
                in: container,
                debugDescription: "Unsupported ExternalCaptureRequest version \(version)."
            )
        }
        sourceKind = try container.decode(ExternalCaptureSourceKind.self, forKey: .sourceKind)
        receivedAt = try container.decodeIfPresent(Date.self, forKey: .receivedAt)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        text = try container.decode(String.self, forKey: .text)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        context = try container.decodeIfPresent(String.self, forKey: .context)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        evidenceItems = try container.decodeIfPresent([ExternalCaptureEvidenceItem].self, forKey: .evidenceItems) ?? []
        affectEvidence = try container.decodeIfPresent([ExternalCaptureAffectEvidence].self, forKey: .affectEvidence) ?? []
        attachments = try container.decodeIfPresent([ExternalCaptureAttachmentDraft].self, forKey: .attachments) ?? []
        diagnostics = try container.decodeIfPresent([String].self, forKey: .diagnostics) ?? []
    }
}

struct JournalingSuggestionDraft: Codable, Hashable, Sendable {
    static let currentVersion = 3

    var version: Int
    var title: String?
    var body: String?
    var bundle: JournalingEvidenceBundle
    var createdAt: Date

    init(
        version: Int = Self.currentVersion,
        title: String? = nil,
        body: String? = nil,
        bundle: JournalingEvidenceBundle = JournalingEvidenceBundle(),
        createdAt: Date = .now,
        diagnostics: [String] = []
    ) {
        self.version = version
        self.title = title
        self.body = body
        var normalizedBundle = bundle
        if !diagnostics.isEmpty {
            normalizedBundle.diagnostics.append(contentsOf: diagnostics)
        }
        self.bundle = normalizedBundle
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case version, title, body, bundle, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        guard version == Self.currentVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .version,
                in: container,
                debugDescription: "Unsupported JournalingSuggestionDraft version \(version)."
            )
        }
        title = try container.decodeIfPresent(String.self, forKey: .title)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        bundle = try container.decodeIfPresent(JournalingEvidenceBundle.self, forKey: .bundle) ?? JournalingEvidenceBundle()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }

    var evidenceItems: [ExternalCaptureEvidenceItem] { bundle.flattenedEvidenceItems }
    var affectEvidence: [ExternalCaptureAffectEvidence] { bundle.stateOfMind }
    var attachments: [ExternalCaptureAttachmentDraft] { bundle.attachments }
    var diagnostics: [String] { bundle.diagnostics }
}
