import Foundation

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

    var displayLabel: String {
        switch self {
        case .pending: String(localized: "status.pending")
        case .imported: String(localized: "status.imported")
        case .dismissed: String(localized: "status.dismissed")
        }
    }
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
