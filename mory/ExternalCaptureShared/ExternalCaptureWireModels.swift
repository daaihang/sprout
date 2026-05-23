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

struct JournalingLocationEvidence: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String?
    var place: String?
    var city: String?
    var latitude: Double?
    var longitude: Double?
    var isWorkLocation: Bool?
    var startedAt: Date?
    var metadata: [String: String]

    init(id: UUID = UUID(), title: String? = nil, place: String? = nil, city: String? = nil, latitude: Double? = nil, longitude: Double? = nil, isWorkLocation: Bool? = nil, startedAt: Date? = nil, metadata: [String: String] = [:]) {
        self.id = id
        self.title = title
        self.place = place
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.isWorkLocation = isWorkLocation
        self.startedAt = startedAt
        self.metadata = metadata
    }
}

struct JournalingMediaEvidence: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, CaseIterable, Identifiable, Sendable {
        case song
        case podcast
        case genericMedia

        var id: String { rawValue }
    }

    var id: UUID
    var kind: Kind
    var title: String?
    var artist: String?
    var albumOrShow: String?
    var startedAt: Date?
    var artworkAttachmentID: UUID?
    var metadata: [String: String]

    init(id: UUID = UUID(), kind: Kind, title: String? = nil, artist: String? = nil, albumOrShow: String? = nil, startedAt: Date? = nil, artworkAttachmentID: UUID? = nil, metadata: [String: String] = [:]) {
        self.id = id
        self.kind = kind
        self.title = title
        self.artist = artist
        self.albumOrShow = albumOrShow
        self.startedAt = startedAt
        self.artworkAttachmentID = artworkAttachmentID
        self.metadata = metadata
    }
}

struct JournalingPhotoVideoEvidence: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, CaseIterable, Identifiable, Sendable {
        case photo
        case video
        case livePhotoImage
        case livePhotoVideo

        var id: String { rawValue }
    }

    var id: UUID
    var kind: Kind
    var startedAt: Date?
    var attachmentID: UUID?
    var metadata: [String: String]

    init(id: UUID = UUID(), kind: Kind, startedAt: Date? = nil, attachmentID: UUID? = nil, metadata: [String: String] = [:]) {
        self.id = id
        self.kind = kind
        self.startedAt = startedAt
        self.attachmentID = attachmentID
        self.metadata = metadata
    }
}

struct JournalingActivityEvidence: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, CaseIterable, Identifiable, Sendable {
        case workout
        case workoutGroup
        case motionActivity

        var id: String { rawValue }
    }

    var id: UUID
    var kind: Kind
    var title: String?
    var summary: String?
    var startedAt: Date?
    var endedAt: Date?
    var iconAttachmentID: UUID?
    var metadata: [String: String]

    init(id: UUID = UUID(), kind: Kind, title: String? = nil, summary: String? = nil, startedAt: Date? = nil, endedAt: Date? = nil, iconAttachmentID: UUID? = nil, metadata: [String: String] = [:]) {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.iconAttachmentID = iconAttachmentID
        self.metadata = metadata
    }
}

struct JournalingContactEvidence: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var photoAttachmentID: UUID?
    var metadata: [String: String]

    init(id: UUID = UUID(), name: String, photoAttachmentID: UUID? = nil, metadata: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.photoAttachmentID = photoAttachmentID
        self.metadata = metadata
    }
}

struct JournalingReflectionEvidence: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var prompt: String
    var colorDescription: String?

    init(id: UUID = UUID(), prompt: String, colorDescription: String? = nil) {
        self.id = id
        self.prompt = prompt
        self.colorDescription = colorDescription
    }
}

struct JournalingEventPosterEvidence: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String?
    var startedAt: Date?
    var endedAt: Date?
    var isHost: Bool?
    var placeName: String?
    var imageAttachmentID: UUID?
    var metadata: [String: String]

    init(id: UUID = UUID(), title: String? = nil, startedAt: Date? = nil, endedAt: Date? = nil, isHost: Bool? = nil, placeName: String? = nil, imageAttachmentID: UUID? = nil, metadata: [String: String] = [:]) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.isHost = isHost
        self.placeName = placeName
        self.imageAttachmentID = imageAttachmentID
        self.metadata = metadata
    }
}

struct JournalingEvidenceBundle: Codable, Hashable, Sendable {
    var locations: [JournalingLocationEvidence]
    var locationGroups: [[JournalingLocationEvidence]]
    var media: [JournalingMediaEvidence]
    var photoVideos: [JournalingPhotoVideoEvidence]
    var activities: [JournalingActivityEvidence]
    var contacts: [JournalingContactEvidence]
    var reflections: [JournalingReflectionEvidence]
    var stateOfMind: [ExternalCaptureAffectEvidence]
    var eventPosters: [JournalingEventPosterEvidence]
    var attachments: [ExternalCaptureAttachmentDraft]
    var diagnostics: [String]

    init(
        locations: [JournalingLocationEvidence] = [],
        locationGroups: [[JournalingLocationEvidence]] = [],
        media: [JournalingMediaEvidence] = [],
        photoVideos: [JournalingPhotoVideoEvidence] = [],
        activities: [JournalingActivityEvidence] = [],
        contacts: [JournalingContactEvidence] = [],
        reflections: [JournalingReflectionEvidence] = [],
        stateOfMind: [ExternalCaptureAffectEvidence] = [],
        eventPosters: [JournalingEventPosterEvidence] = [],
        attachments: [ExternalCaptureAttachmentDraft] = [],
        diagnostics: [String] = []
    ) {
        self.locations = locations
        self.locationGroups = locationGroups
        self.media = media
        self.photoVideos = photoVideos
        self.activities = activities
        self.contacts = contacts
        self.reflections = reflections
        self.stateOfMind = stateOfMind
        self.eventPosters = eventPosters
        self.attachments = attachments
        self.diagnostics = diagnostics
    }

    var flattenedEvidenceItems: [ExternalCaptureEvidenceItem] {
        var items: [ExternalCaptureEvidenceItem] = []
        items += locations.map {
            ExternalCaptureEvidenceItem(
                kind: .location,
                title: $0.title,
                startedAt: $0.startedAt,
                metadata: $0.metadata
                    .merging([
                        "place": $0.place ?? "",
                        "city": $0.city ?? "",
                        "latitude": $0.latitude.map { String($0) } ?? "",
                        "longitude": $0.longitude.map { String($0) } ?? "",
                        "isWorkLocation": $0.isWorkLocation.map { String($0) } ?? ""
                    ].filter { !$0.value.isEmpty }) { _, new in new }
            )
        }
        items += locationGroups.map { group in
            ExternalCaptureEvidenceItem(
                kind: .locationGroup,
                title: "Location group",
                value: group.compactMap(\.title).joined(separator: ", ")
            )
        }
        items += media.map {
            ExternalCaptureEvidenceItem(
                kind: $0.kind.externalEvidenceKind,
                title: $0.title,
                startedAt: $0.startedAt,
                metadata: $0.metadata
                    .merging([
                        "artist": $0.artist ?? "",
                        "albumOrShow": $0.albumOrShow ?? "",
                        "artworkAttachmentID": $0.artworkAttachmentID?.uuidString ?? ""
                    ].filter { !$0.value.isEmpty }) { _, new in new }
            )
        }
        items += photoVideos.map {
            ExternalCaptureEvidenceItem(
                kind: $0.kind.externalEvidenceKind,
                title: $0.kind.rawValue,
                startedAt: $0.startedAt,
                metadata: $0.metadata.merging(["attachmentID": $0.attachmentID?.uuidString ?? ""].filter { !$0.value.isEmpty }) { _, new in new }
            )
        }
        items += activities.map {
            ExternalCaptureEvidenceItem(
                kind: $0.kind.externalEvidenceKind,
                title: $0.title,
                summary: $0.summary,
                startedAt: $0.startedAt,
                endedAt: $0.endedAt,
                metadata: $0.metadata
            )
        }
        items += contacts.map {
            ExternalCaptureEvidenceItem(kind: .contact, title: $0.name, metadata: $0.metadata)
        }
        items += reflections.map {
            ExternalCaptureEvidenceItem(kind: .reflection, title: "Reflection prompt", value: $0.prompt)
        }
        items += stateOfMind.map {
            ExternalCaptureEvidenceItem(
                kind: .stateOfMind,
                title: $0.label ?? $0.labels.first,
                value: $0.valenceClassification,
                metadata: $0.metadata
            )
        }
        items += eventPosters.map {
            ExternalCaptureEvidenceItem(
                kind: .eventPoster,
                title: $0.title,
                startedAt: $0.startedAt,
                endedAt: $0.endedAt,
                metadata: $0.metadata
                    .merging([
                        "placeName": $0.placeName ?? "",
                        "isHost": $0.isHost.map { String($0) } ?? "",
                        "imageAttachmentID": $0.imageAttachmentID?.uuidString ?? ""
                    ].filter { !$0.value.isEmpty }) { _, new in new }
            )
        }
        return items
    }
}

private extension JournalingMediaEvidence.Kind {
    var externalEvidenceKind: ExternalCaptureEvidenceKind {
        switch self {
        case .song: return .song
        case .podcast: return .podcast
        case .genericMedia: return .genericMedia
        }
    }
}

private extension JournalingPhotoVideoEvidence.Kind {
    var externalEvidenceKind: ExternalCaptureEvidenceKind {
        switch self {
        case .photo: return .photo
        case .video: return .video
        case .livePhotoImage, .livePhotoVideo: return .livePhoto
        }
    }
}

private extension JournalingActivityEvidence.Kind {
    var externalEvidenceKind: ExternalCaptureEvidenceKind {
        switch self {
        case .workout: return .workout
        case .workoutGroup: return .workoutGroup
        case .motionActivity: return .motionActivity
        }
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
