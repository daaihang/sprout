import Foundation

enum CaptureOriginCategory: String, Codable, Hashable, Sendable, CaseIterable {
    case userInput
    case autoContext
    case externalImport
    case aiInferred
    case debug

    var artifactOrigin: CaptureArtifactOrigin {
        switch self {
        case .userInput, .debug:
            return .manual
        case .autoContext:
            return .context
        case .externalImport:
            return .imported
        case .aiInferred:
            return .inferred
        }
    }
}

enum CaptureProvenanceSourceKind: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case composer
    case voice
    case camera
    case photoLibrary
    case audioRecorder
    case linkComposer
    case musicPicker
    case locationPicker
    case todoComposer
    case moodPicker
    case autoContext
    case shareSheet
    case appIntent
    case shortcut
    case widget
    case journalingSuggestion
    case health
    case fitness
    case aiAnalysis
    case debugFixture
    case unknown

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .composer:
            return "Composer"
        case .voice:
            return "Voice"
        case .camera:
            return "Camera"
        case .photoLibrary:
            return "Photo Library"
        case .audioRecorder:
            return "Audio"
        case .linkComposer:
            return "Link"
        case .musicPicker:
            return "Music"
        case .locationPicker:
            return "Location"
        case .todoComposer:
            return "Todo"
        case .moodPicker:
            return "Mood"
        case .autoContext:
            return "Context"
        case .shareSheet:
            return "Share"
        case .appIntent:
            return "App Intent"
        case .shortcut:
            return "Shortcut"
        case .widget:
            return "Widget"
        case .journalingSuggestion:
            return "Journaling"
        case .health:
            return "Health"
        case .fitness:
            return "Fitness"
        case .aiAnalysis:
            return "AI"
        case .debugFixture:
            return "Debug"
        case .unknown:
            return "Unknown"
        }
    }

    var derivedCaptureSource: CaptureSource {
        switch self {
        case .voice:
            return .voice
        case .audioRecorder:
            return .audio
        case .camera, .photoLibrary:
            return .photo
        case .shareSheet, .appIntent, .shortcut, .widget:
            return .importFile
        case .composer,
             .linkComposer,
             .musicPicker,
             .locationPicker,
             .todoComposer,
             .moodPicker,
             .autoContext,
             .journalingSuggestion,
             .health,
             .fitness:
            return .composer
        case .aiAnalysis, .debugFixture, .unknown:
            return .manual
        }
    }
}

struct CaptureProvenance: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var originCategory: CaptureOriginCategory
    var sourceKind: CaptureProvenanceSourceKind
    var importSessionID: UUID?
    var externalInboxItemID: UUID?
    var journalingEvidenceID: UUID?
    var sourceDisplayName: String?
    var attachmentRole: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        originCategory: CaptureOriginCategory,
        sourceKind: CaptureProvenanceSourceKind,
        importSessionID: UUID? = nil,
        externalInboxItemID: UUID? = nil,
        journalingEvidenceID: UUID? = nil,
        sourceDisplayName: String? = nil,
        attachmentRole: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.originCategory = originCategory
        self.sourceKind = sourceKind
        self.importSessionID = importSessionID
        self.externalInboxItemID = externalInboxItemID
        self.journalingEvidenceID = journalingEvidenceID
        self.sourceDisplayName = sourceDisplayName
        self.attachmentRole = attachmentRole
        self.createdAt = createdAt
    }

    static var manualComposer: CaptureProvenance {
        CaptureProvenance(originCategory: .userInput, sourceKind: .composer)
    }

    static var manualVoice: CaptureProvenance {
        CaptureProvenance(originCategory: .userInput, sourceKind: .voice)
    }

    static var manualCamera: CaptureProvenance {
        CaptureProvenance(originCategory: .userInput, sourceKind: .camera)
    }

    static var autoContext: CaptureProvenance {
        CaptureProvenance(originCategory: .autoContext, sourceKind: .autoContext)
    }

    static var aiInferred: CaptureProvenance {
        CaptureProvenance(originCategory: .aiInferred, sourceKind: .aiAnalysis)
    }

    static func external(
        sourceKind: CaptureProvenanceSourceKind,
        importSessionID: UUID = UUID(),
        externalInboxItemID: UUID? = nil,
        sourceDisplayName: String? = nil,
        createdAt: Date = .now
    ) -> CaptureProvenance {
        CaptureProvenance(
            originCategory: .externalImport,
            sourceKind: sourceKind,
            importSessionID: importSessionID,
            externalInboxItemID: externalInboxItemID,
            sourceDisplayName: sourceDisplayName,
            createdAt: createdAt
        )
    }

    func withExternalInboxItemID(_ id: UUID?) -> CaptureProvenance {
        var copy = self
        copy.externalInboxItemID = id
        return copy
    }

    func withJournalingEvidenceID(_ id: UUID?) -> CaptureProvenance {
        var copy = self
        copy.journalingEvidenceID = id
        return copy
    }

    func withAttachmentRole(_ role: String?) -> CaptureProvenance {
        var copy = self
        copy.attachmentRole = role
        return copy
    }

    var artifactOrigin: CaptureArtifactOrigin {
        originCategory.artifactOrigin
    }

    var derivedCaptureSource: CaptureSource {
        sourceKind.derivedCaptureSource
    }

    var displayLabel: String {
        sourceDisplayName?.trimmedOrNil ?? sourceKind.displayLabel
    }

    var compactDebugLabel: String {
        [
            originCategory.rawValue,
            sourceKind.rawValue,
            importSessionID.map { "session=\($0.uuidString.prefix(8))" },
            externalInboxItemID.map { "inbox=\($0.uuidString.prefix(8))" },
            journalingEvidenceID.map { "evidence=\($0.uuidString.prefix(8))" },
            attachmentRole.map { "role=\($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    var metadata: [String: String] {
        var metadata: [String: String] = [
            "captureOriginCategory": originCategory.rawValue,
            "captureSourceKind": sourceKind.rawValue,
            "captureProvenanceID": id.uuidString,
            "captureProvenanceCreatedAt": createdAt.formatted(.iso8601)
        ]
        if let importSessionID { metadata["captureImportSessionID"] = importSessionID.uuidString }
        if let externalInboxItemID { metadata["externalInboxItemID"] = externalInboxItemID.uuidString }
        if let journalingEvidenceID { metadata["journalingEvidenceID"] = journalingEvidenceID.uuidString }
        if let sourceDisplayName = sourceDisplayName?.trimmedOrNil { metadata["captureSourceDisplayName"] = sourceDisplayName }
        if let attachmentRole = attachmentRole?.trimmedOrNil { metadata["captureAttachmentRole"] = attachmentRole }
        return metadata
    }
}

extension CaptureSource {
    var defaultProvenance: CaptureProvenance {
        CaptureProvenance(
            originCategory: defaultOriginCategory,
            sourceKind: defaultProvenanceSourceKind
        )
    }

    var defaultOriginCategory: CaptureOriginCategory {
        switch self {
        case .importFile:
            return .externalImport
        case .manual:
            return .debug
        case .composer, .voice, .photo, .audio:
            return .userInput
        }
    }

    var defaultProvenanceSourceKind: CaptureProvenanceSourceKind {
        switch self {
        case .composer:
            return .composer
        case .voice:
            return .voice
        case .photo:
            return .photoLibrary
        case .audio:
            return .audioRecorder
        case .importFile:
            return .shareSheet
        case .manual:
            return .unknown
        }
    }
}
