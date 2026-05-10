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
    var sortIndex: Int = 0
    @Attribute(.externalStorage) var imageData: Data? = nil
    @Attribute(.externalStorage) var audioData: Data? = nil
    @Attribute(.externalStorage) var thumbnailData: Data? = nil

    @Relationship(inverse: \Record.mediaCards) var record: Record? = nil

    init() {}
}
