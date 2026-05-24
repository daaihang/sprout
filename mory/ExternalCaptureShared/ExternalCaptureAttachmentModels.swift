import Foundation

enum ExternalCaptureAttachmentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case image
    case video
    case file

    var id: String { rawValue }
}

enum ExternalCaptureAttachmentRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case primaryMedia
    case artwork
    case icon
    case contactPhoto
    case eventPosterImage
    case diagnostic
    case unknown

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

struct ExternalCaptureAttachmentDraft: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var kind: ExternalCaptureAttachmentKind
    var role: ExternalCaptureAttachmentRole
    var referenceID: UUID?
    var filename: String
    var contentType: String
    var storedFileName: String?
    var summary: String?
    var diagnostics: [String]

    init(
        id: UUID = UUID(),
        kind: ExternalCaptureAttachmentKind = .file,
        role: ExternalCaptureAttachmentRole = .primaryMedia,
        referenceID: UUID? = nil,
        filename: String,
        contentType: String,
        storedFileName: String? = nil,
        summary: String? = nil,
        diagnostics: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.role = role
        self.referenceID = referenceID
        self.filename = filename
        self.contentType = contentType
        self.storedFileName = storedFileName
        self.summary = summary
        self.diagnostics = diagnostics
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, role, referenceID, filename, contentType, storedFileName, summary, diagnostics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decodeIfPresent(ExternalCaptureAttachmentKind.self, forKey: .kind) ?? .file
        role = try container.decodeIfPresent(ExternalCaptureAttachmentRole.self, forKey: .role) ?? .primaryMedia
        referenceID = try container.decodeIfPresent(UUID.self, forKey: .referenceID)
        filename = try container.decode(String.self, forKey: .filename)
        contentType = try container.decode(String.self, forKey: .contentType)
        storedFileName = try container.decodeIfPresent(String.self, forKey: .storedFileName)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        diagnostics = try container.decodeIfPresent([String].self, forKey: .diagnostics) ?? []
    }
}
