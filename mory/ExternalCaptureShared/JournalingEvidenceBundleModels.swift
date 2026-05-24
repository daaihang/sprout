import Foundation

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
