import Foundation

enum CaptureComposerSheet: String, Identifiable, CaseIterable, Equatable {
    case camera
    case audio
    case link
    case music
    case location
    case todo
    case mood
    case journalingFallback

    var id: String { rawValue }
}

struct CaptureComposerSheetCoordinator: Equatable {
    var activeSheet: CaptureComposerSheet?
    var isPresentingAppleJournalingPicker = false

    mutating func present(_ sheet: CaptureComposerSheet) {
        activeSheet = sheet
    }

    mutating func dismissSheet() {
        activeSheet = nil
    }

    mutating func presentAppleJournalingPicker() {
        isPresentingAppleJournalingPicker = true
    }

    mutating func dismissAppleJournalingPicker() {
        isPresentingAppleJournalingPicker = false
    }

    mutating func presentJournalingImport(isApplePickerAvailable: Bool) {
        if isApplePickerAvailable {
            presentAppleJournalingPicker()
        } else {
            present(.journalingFallback)
        }
    }
}
