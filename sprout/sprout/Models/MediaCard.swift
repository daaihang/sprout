import Foundation
import SwiftData

@Model
final class MediaCard {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var type: String = "photo"
    var url: String? = nil
    var title: String? = nil
    var caption: String? = nil
    var albumName: String? = nil
    var artworkURLString: String? = nil
    var sortIndex: Int = 0
    @Attribute(.externalStorage) var imageData: Data? = nil
    @Attribute(.externalStorage) var audioData: Data? = nil
    @Attribute(.externalStorage) var thumbnailData: Data? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var locationName: String? = nil
    var aiDescription: String? = nil
    var capturedAt: Date? = nil

    @Relationship(inverse: \Record.mediaCards) var record: Record? = nil

    init() {}
}
