import Foundation

enum MorySharedContainers {
    static let appGroupIdentifier = "group.com.speculolabs.mory"
    static let externalCaptureAttachmentDirectoryName = "ExternalCaptureAttachments"

    static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static var appGroupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
}

struct ExternalCaptureAttachmentFileStore: Sendable {
    func saveData(_ data: Data, preferredFilename: String) throws -> String {
        guard let directory = Self.attachmentDirectoryURL() else {
            throw ExternalCaptureInboxError.appGroupUnavailable
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sanitized = preferredFilename
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let filename = "\(UUID().uuidString)-\(sanitized)"
        let url = directory.appendingPathComponent(filename, isDirectory: false)
        try data.write(to: url, options: .atomic)
        return filename
    }

    func saveImage(data: Data, preferredFilename: String) throws -> String {
        try saveData(data, preferredFilename: preferredFilename)
    }

    func loadData(storedFileName: String) throws -> Data? {
        guard let directory = Self.attachmentDirectoryURL() else { return nil }
        let url = directory.appendingPathComponent(storedFileName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    static func attachmentDirectoryURL() -> URL? {
        MorySharedContainers.appGroupContainerURL?
            .appendingPathComponent(MorySharedContainers.externalCaptureAttachmentDirectoryName, isDirectory: true)
    }
}

enum ExternalCaptureSourceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case appIntent
    case shortcut
    case shareSheet
    case journalingSuggestion
    case health
    case fitness
    case unknown

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

enum ExternalCaptureAttachmentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case image
    case video
    case file

    var id: String { rawValue }
}

struct ExternalCaptureAttachmentDraft: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var kind: ExternalCaptureAttachmentKind
    var filename: String
    var contentType: String
    var storedFileName: String?
    var summary: String?
    var diagnostics: [String]

    init(
        id: UUID = UUID(),
        kind: ExternalCaptureAttachmentKind = .file,
        filename: String,
        contentType: String,
        storedFileName: String? = nil,
        summary: String? = nil,
        diagnostics: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.filename = filename
        self.contentType = contentType
        self.storedFileName = storedFileName
        self.summary = summary
        self.diagnostics = diagnostics
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, filename, contentType, storedFileName, summary, diagnostics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decodeIfPresent(ExternalCaptureAttachmentKind.self, forKey: .kind) ?? .file
        filename = try container.decode(String.self, forKey: .filename)
        contentType = try container.decode(String.self, forKey: .contentType)
        storedFileName = try container.decodeIfPresent(String.self, forKey: .storedFileName)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        diagnostics = try container.decodeIfPresent([String].self, forKey: .diagnostics) ?? []
    }
}

enum ExternalCaptureEvidenceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case link
    case location
    case locationGroup
    case song
    case podcast
    case genericMedia
    case photo
    case video
    case livePhoto
    case workout
    case workoutGroup
    case motionActivity
    case contact
    case reflection
    case stateOfMind
    case eventPoster
    case diagnostic

    var id: String { rawValue }
}

struct ExternalCaptureEvidenceItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var kind: ExternalCaptureEvidenceKind
    var title: String?
    var summary: String?
    var value: String?
    var startedAt: Date?
    var endedAt: Date?
    var metadata: [String: String]

    init(
        id: UUID = UUID(),
        kind: ExternalCaptureEvidenceKind,
        title: String? = nil,
        summary: String? = nil,
        value: String? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
        self.value = value
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.metadata = metadata
    }
}

enum ExternalCaptureAffectSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case userSelected
    case journalSuggestionStateOfMind
    case healthStateOfMind
    case fitnessContext
    case unknown

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

struct ExternalCaptureAffectEvidence: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var source: ExternalCaptureAffectSource
    var label: String?
    var labels: [String]
    var toneHints: [String]
    var associations: [String]
    var valence: Double?
    var valenceClassification: String?
    var kind: String?
    var rawInput: String?
    var confidence: Double?
    var userConfirmed: Bool
    var metadata: [String: String]

    init(
        id: UUID = UUID(),
        source: ExternalCaptureAffectSource,
        label: String? = nil,
        labels: [String] = [],
        toneHints: [String] = [],
        associations: [String] = [],
        valence: Double? = nil,
        valenceClassification: String? = nil,
        kind: String? = nil,
        rawInput: String? = nil,
        confidence: Double? = nil,
        userConfirmed: Bool = true,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.source = source
        self.label = label
        self.labels = labels
        self.toneHints = toneHints
        self.associations = associations
        self.valence = valence
        self.valenceClassification = valenceClassification
        self.kind = kind
        self.rawInput = rawInput
        self.confidence = confidence
        self.userConfirmed = userConfirmed
        self.metadata = metadata
    }
}

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
    static let currentVersion = 2

    var version: Int
    var title: String?
    var body: String?
    var evidenceItems: [ExternalCaptureEvidenceItem]
    var affectEvidence: [ExternalCaptureAffectEvidence]
    var attachments: [ExternalCaptureAttachmentDraft]
    var createdAt: Date
    var diagnostics: [String]

    init(
        version: Int = Self.currentVersion,
        title: String? = nil,
        body: String? = nil,
        evidenceItems: [ExternalCaptureEvidenceItem] = [],
        affectEvidence: [ExternalCaptureAffectEvidence] = [],
        attachments: [ExternalCaptureAttachmentDraft] = [],
        createdAt: Date = .now,
        diagnostics: [String] = []
    ) {
        self.version = version
        self.title = title
        self.body = body
        self.evidenceItems = evidenceItems
        self.affectEvidence = affectEvidence
        self.attachments = attachments
        self.createdAt = createdAt
        self.diagnostics = diagnostics
    }

    private enum CodingKeys: String, CodingKey {
        case version, title, body, evidenceItems, affectEvidence, attachments, createdAt, diagnostics
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
        evidenceItems = try container.decodeIfPresent([ExternalCaptureEvidenceItem].self, forKey: .evidenceItems) ?? []
        affectEvidence = try container.decodeIfPresent([ExternalCaptureAffectEvidence].self, forKey: .affectEvidence) ?? []
        attachments = try container.decodeIfPresent([ExternalCaptureAttachmentDraft].self, forKey: .attachments) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        diagnostics = try container.decodeIfPresent([String].self, forKey: .diagnostics) ?? []
    }
}

enum ExternalCaptureInboxPayloadKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case externalCapture
    case journalingSuggestion

    var id: String { rawValue }
}

enum ExternalCaptureInboxStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case pending
    case imported
    case dismissed

    var id: String { rawValue }
}

struct ExternalCaptureInboxItem: Identifiable, Codable, Hashable, Sendable {
    static let currentVersion = 2

    var version: Int
    var id: UUID
    var payloadKind: ExternalCaptureInboxPayloadKind
    var sourceKind: ExternalCaptureSourceKind
    var title: String?
    var summary: String
    var payloadData: Data
    var status: ExternalCaptureInboxStatus
    var receivedAt: Date
    var updatedAt: Date
    var importedRecordID: UUID?
    var dismissedAt: Date?
    var errorMessage: String?

    init(
        version: Int = Self.currentVersion,
        id: UUID = UUID(),
        payloadKind: ExternalCaptureInboxPayloadKind,
        sourceKind: ExternalCaptureSourceKind,
        title: String? = nil,
        summary: String,
        payloadData: Data,
        status: ExternalCaptureInboxStatus = .pending,
        receivedAt: Date = .now,
        updatedAt: Date = .now,
        importedRecordID: UUID? = nil,
        dismissedAt: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.version = version
        self.id = id
        self.payloadKind = payloadKind
        self.sourceKind = sourceKind
        self.title = title
        self.summary = summary
        self.payloadData = payloadData
        self.status = status
        self.receivedAt = receivedAt
        self.updatedAt = updatedAt
        self.importedRecordID = importedRecordID
        self.dismissedAt = dismissedAt
        self.errorMessage = errorMessage
    }

    private enum CodingKeys: String, CodingKey {
        case version, id, payloadKind, sourceKind, title, summary, payloadData, status, receivedAt, updatedAt
        case importedRecordID, dismissedAt, errorMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        guard version == Self.currentVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .version,
                in: container,
                debugDescription: "Unsupported ExternalCaptureInboxItem version \(version)."
            )
        }
        id = try container.decode(UUID.self, forKey: .id)
        payloadKind = try container.decode(ExternalCaptureInboxPayloadKind.self, forKey: .payloadKind)
        sourceKind = try container.decode(ExternalCaptureSourceKind.self, forKey: .sourceKind)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        payloadData = try container.decode(Data.self, forKey: .payloadData)
        status = try container.decode(ExternalCaptureInboxStatus.self, forKey: .status)
        receivedAt = try container.decode(Date.self, forKey: .receivedAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        importedRecordID = try container.decodeIfPresent(UUID.self, forKey: .importedRecordID)
        dismissedAt = try container.decodeIfPresent(Date.self, forKey: .dismissedAt)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
    }
}

enum ExternalCaptureInboxError: LocalizedError, Equatable {
    case appGroupUnavailable
    case unsupportedPayload
    case unsupportedImagePayload
    case unsupportedPayloadKind(String)
    case itemIsNotPending

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            "Mory App Group storage is unavailable."
        case .unsupportedPayload:
            "This shared item is not supported."
        case .unsupportedImagePayload:
            "Mory could not read this image."
        case let .unsupportedPayloadKind(kind):
            "Unsupported external capture payload kind: \(kind)."
        case .itemIsNotPending:
            "External capture item is not pending."
        }
    }
}
