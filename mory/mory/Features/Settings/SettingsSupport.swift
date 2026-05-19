import AVFoundation
import Foundation
import MusicKit
import Photos
import Speech
import SwiftUI
import UIKit

enum SettingsPermissionID: String, CaseIterable, Identifiable, Sendable {
    case location
    case photos
    case microphone
    case speech
    case music
    case weather

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .location: "settings.permission.location"
        case .photos: "settings.permission.photos"
        case .microphone: "settings.permission.microphone"
        case .speech: "settings.permission.speech"
        case .music: "settings.permission.music"
        case .weather: "settings.permission.weather"
        }
    }

    var explanationKey: LocalizedStringKey {
        switch self {
        case .location: "settings.permission.location.explain"
        case .photos: "settings.permission.photos.explain"
        case .microphone: "settings.permission.microphone.explain"
        case .speech: "settings.permission.speech.explain"
        case .music: "settings.permission.music.explain"
        case .weather: "settings.permission.weather.explain"
        }
    }

    var systemImage: String {
        switch self {
        case .location: "location"
        case .photos: "photo"
        case .microphone: "mic"
        case .speech: "waveform"
        case .music: "music.note"
        case .weather: "cloud.sun"
        }
    }
}

enum SettingsPermissionStatus: String, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case limited
    case unavailable

    var titleKey: LocalizedStringKey {
        switch self {
        case .notDetermined: "settings.permission.status.notDetermined"
        case .authorized: "settings.permission.status.authorized"
        case .denied: "settings.permission.status.denied"
        case .restricted: "settings.permission.status.restricted"
        case .limited: "settings.permission.status.limited"
        case .unavailable: "settings.permission.status.unavailable"
        }
    }

    var canRequest: Bool {
        self == .notDetermined
    }

    var canOpenSettings: Bool {
        self == .denied || self == .restricted || self == .limited
    }
}

struct SettingsPermissionSnapshot: Identifiable, Hashable, Sendable {
    let id: SettingsPermissionID
    let status: SettingsPermissionStatus

    var canRequest: Bool { status.canRequest && id != .weather }
    var canOpenSettings: Bool { status.canOpenSettings }
}

enum SettingsPermissionSnapshotBuilder {
    static func make(
        locationStatus: ContextPermissionManager.Status,
        musicStatus: ContextPermissionManager.Status,
        photosStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite),
        microphoneStatus: AVAudioApplication.recordPermission = AVAudioApplication.shared.recordPermission,
        speechStatus: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()
    ) -> [SettingsPermissionSnapshot] {
        let mappedLocation = mapContextPermission(locationStatus)
        return [
            SettingsPermissionSnapshot(id: .location, status: mappedLocation),
            SettingsPermissionSnapshot(id: .photos, status: mapPhotos(photosStatus)),
            SettingsPermissionSnapshot(id: .microphone, status: mapMicrophone(microphoneStatus)),
            SettingsPermissionSnapshot(id: .speech, status: mapSpeech(speechStatus)),
            SettingsPermissionSnapshot(id: .music, status: mapContextPermission(musicStatus)),
            SettingsPermissionSnapshot(id: .weather, status: weatherStatus(locationStatus: mappedLocation))
        ]
    }

    private static func mapContextPermission(_ status: ContextPermissionManager.Status) -> SettingsPermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        }
    }

    private static func mapPhotos(_ status: PHAuthorizationStatus) -> SettingsPermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorized: .authorized
        case .limited: .limited
        @unknown default: .unavailable
        }
    }

    private static func mapMicrophone(_ status: AVAudioApplication.recordPermission) -> SettingsPermissionStatus {
        switch status {
        case .undetermined: .notDetermined
        case .denied: .denied
        case .granted: .authorized
        @unknown default: .unavailable
        }
    }

    private static func mapSpeech(_ status: SFSpeechRecognizerAuthorizationStatus) -> SettingsPermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        case .authorized: .authorized
        @unknown default: .unavailable
        }
    }

    private static func weatherStatus(locationStatus: SettingsPermissionStatus) -> SettingsPermissionStatus {
        switch locationStatus {
        case .authorized, .limited: .authorized
        case .denied, .restricted: .unavailable
        case .notDetermined: .notDetermined
        case .unavailable: .unavailable
        }
    }
}

extension UserSettingsAppearanceMode {
    var titleKey: LocalizedStringKey {
        switch self {
        case .system: "settings.appearance.mode.system"
        case .light: "settings.appearance.mode.light"
        case .dark: "settings.appearance.mode.dark"
        }
    }
}

extension UserSettingsContextSelection {
    var titleKey: LocalizedStringKey {
        switch self {
        case .allAvailable: "settings.capture.context.all"
        case .locationWeatherOnly: "settings.capture.context.locationWeather"
        case .manual: "settings.capture.context.manual"
        }
    }
}

extension UserSettingsInsightFrequency {
    var titleKey: LocalizedStringKey {
        switch self {
        case .low: "settings.capture.insight.low"
        case .balanced: "settings.capture.insight.balanced"
        case .high: "settings.capture.insight.high"
        }
    }
}

extension UserSettingsPromptTone {
    var titleKey: LocalizedStringKey {
        switch self {
        case .concise: "settings.capture.tone.concise"
        case .balanced: "settings.capture.tone.balanced"
        case .reflective: "settings.capture.tone.reflective"
        }
    }
}

struct SettingsLocalDataExportSnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let exportedAt: Date
    let settings: UserSettingsPreference
    let memories: [SettingsExportMemory]
    let temporalArcs: [SettingsExportArc]
    let reflections: [SettingsExportReflection]

    @MainActor
    static func make(repository: any MoryMemoryRepositorying, exportedAt: Date = .now) throws -> SettingsLocalDataExportSnapshot {
        let settings = try repository.fetchUserSettingsPreference()
        let memories = try repository.fetchRecentMemories(limit: nil).map { summary in
            let detail = try repository.fetchMemoryDetail(recordID: summary.record.id)
            return SettingsExportMemory(summary: summary, detail: detail)
        }
        let arcs = try repository.fetchTemporalArcSummaries(limit: nil).map { SettingsExportArc(summary: $0) }
        let reflections = try repository.fetchReflectionSummaries(limit: nil).map { SettingsExportReflection(summary: $0) }
        return SettingsLocalDataExportSnapshot(
            schemaVersion: 1,
            exportedAt: exportedAt,
            settings: settings,
            memories: memories,
            temporalArcs: arcs,
            reflections: reflections
        )
    }

    func encodedData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

struct SettingsExportMemory: Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let rawText: String
    let mood: String?
    let inputContext: String?
    let captureSource: String
    let createdAt: Date
    let updatedAt: Date
    let artifactCount: Int
    let pipelineStatus: String?
    let artifacts: [SettingsExportArtifact]

    init(summary: MemorySummary, detail: MemoryDetailSnapshot?) {
        id = summary.record.id
        title = summary.title
        rawText = summary.record.rawText
        mood = summary.record.userMood
        inputContext = summary.record.inputContext
        captureSource = summary.record.captureSource.rawValue
        createdAt = summary.record.createdAt
        updatedAt = summary.record.updatedAt
        artifactCount = summary.artifactCount
        pipelineStatus = summary.pipelineStatus?.stage.rawValue
        artifacts = (detail?.artifacts ?? ([summary.primaryArtifact].compactMap { $0 } + summary.contextArtifacts))
            .map(SettingsExportArtifact.init)
    }
}

struct SettingsExportArtifact: Codable, Equatable, Sendable {
    let id: UUID
    let kind: String
    let title: String
    let summary: String
    let textContent: String
    let metadata: [String: String]
    let mediaFilename: String?
    let mediaMimeType: String?
    let binaryByteCount: Int?
    let previewByteCount: Int?

    nonisolated init(artifact: Artifact) {
        id = artifact.id
        kind = artifact.kind.rawValue
        title = artifact.title
        summary = artifact.summary
        textContent = artifact.textContent
        metadata = artifact.metadata
        mediaFilename = artifact.mediaRef?.filename
        mediaMimeType = artifact.mediaRef?.mimeType
        binaryByteCount = artifact.binaryPayload?.count
        previewByteCount = artifact.previewPayload?.count
    }
}

struct SettingsExportArc: Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let summary: String
    let status: String
    let sourceRecordIDs: [UUID]
    let relatedMemoryTitles: [String]
    let updatedAt: Date

    init(summary: TemporalArcSummarySnapshot) {
        self.id = summary.arc.id
        self.title = summary.arc.title
        self.summary = summary.arc.summary
        self.status = summary.arc.status.rawValue
        self.sourceRecordIDs = summary.arc.sourceRecordIDs
        self.relatedMemoryTitles = summary.relatedMemories.map(\.title)
        self.updatedAt = summary.arc.updatedAt
    }
}

struct SettingsExportReflection: Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let body: String
    let status: String
    let confidence: Double
    let sourceRecordIDs: [UUID]
    let relatedMemoryTitles: [String]
    let createdAt: Date

    init(summary: ReflectionSummarySnapshot) {
        self.id = summary.reflection.id
        self.title = summary.reflection.title
        self.body = summary.reflection.body
        self.status = summary.reflection.status.rawValue
        self.confidence = summary.reflection.confidence
        self.sourceRecordIDs = summary.reflection.sourceRecordIDs
        self.relatedMemoryTitles = summary.relatedMemories.map(\.title)
        self.createdAt = summary.reflection.createdAt
    }
}
