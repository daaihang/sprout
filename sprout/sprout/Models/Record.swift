import Foundation
import SwiftData
import Observation

@Model
final class Record {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var captureSourceRawValue: String = CaptureSource.composer.rawValue
    var rawText: String = ""
    var userMood: String? = nil
    var userIntensity: Int? = nil
    var inputContext: String? = nil

    @Transient
    @ObservationIgnored
    var captureSource: CaptureSource {
        get { CaptureSource(rawValue: captureSourceRawValue) ?? .composer }
        set { captureSourceRawValue = newValue.rawValue }
    }

    init() {}
}
