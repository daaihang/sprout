import SwiftUI
import CoreLocation

// MARK: - ComposerActionType

/// Actions triggered by toolbar buttons inside or outside the expanded composer bar.
enum ComposerActionType {
    case addCard    // "+" button → standalone AddCardSheet
    case camera     // camera capture (quick or toolbar)
    case photo      // photo library picker
    case location   // location sheet
    case people     // people sheet
    case music      // music sheet
    case voice      // voice recording (handled internally by the bar)
    case link       // URL — RecordParser already handles typed URLs; no sheet needed
}

// MARK: - ComposerAttachmentKey

/// Identifies which attachment to remove when a chip's × button is tapped.
enum ComposerAttachmentKey {
    case mood, photo, location, music, todo, audio, people
}

// MARK: - ComposerAttachments

/// Transient state accumulating extra data to bundle into the next sent Record.
/// Cleared automatically when the composer bar closes.
struct ComposerAttachments {
    var mood: MoodType? = nil
    var intensity: Int = 3
    var photos: [UIImage] = []
    var locationData: MapCardData? = nil
    var music: MusicCardData? = nil
    var todos: TodoCardData? = nil
    var audioData: Data? = nil
    var people: [Person] = []

    var isEmpty: Bool {
        mood == nil
            && photos.isEmpty
            && locationData == nil
            && music == nil
            && todos == nil
            && audioData == nil
            && people.isEmpty
    }

    var artifactCount: Int {
        (mood == nil ? 0 : 1)
            + photos.count
            + (locationData == nil ? 0 : 1)
            + (music == nil ? 0 : 1)
            + (todos == nil ? 0 : 1)
            + (audioData == nil ? 0 : 1)
            + people.count
    }

    var hasArtifacts: Bool { artifactCount > 0 }

    var artifactCountLabel: String {
        switch artifactCount {
        case 0: "0 artifacts"
        case 1: "1 artifact"
        default: "\(artifactCount) artifacts"
        }
    }

    var captureSummarySegments: [String] {
        var segments: [String] = []
        if let mood {
            segments.append(mood.label)
        }
        if !photos.isEmpty {
            segments.append("\(photos.count) photos")
        }
        if let locationData {
            segments.append(locationData.locationName.isEmpty ? "Location" : locationData.locationName)
        }
        if let music {
            segments.append(music.trackName.isEmpty ? "Music" : music.trackName)
        }
        if !people.isEmpty {
            segments.append("\(people.count) people")
        }
        if todos != nil {
            segments.append("To-Do")
        }
        if audioData != nil {
            segments.append("Voice")
        }
        return segments
    }

    mutating func clear() { self = ComposerAttachments() }
}

/// Formal input boundary for one capture event before it is turned into a record aggregate.
struct CaptureDraft {
    var shellText: String = ""
    var attachments: ComposerAttachments = .init()

    var trimmedShellText: String {
        shellText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasShellText: Bool { !trimmedShellText.isEmpty }
    var hasArtifacts: Bool { attachments.hasArtifacts }
    var hasContent: Bool { hasShellText || !attachments.isEmpty }

    mutating func clear() {
        shellText = ""
        attachments.clear()
    }
}
