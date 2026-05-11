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

    mutating func clear() { self = ComposerAttachments() }
}
