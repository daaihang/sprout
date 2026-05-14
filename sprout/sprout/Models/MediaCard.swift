import Foundation
import SwiftData

@Model
final class MediaCard {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    
    // MARK: - Binary Payloads (New Data Only)
    /// Binary payload backing for artifact renderers. Content truth lives in `Artifact`.
    @Attribute(.externalStorage) var imageData: Data? = nil
    /// Binary payload backing for artifact renderers. Content truth lives in `Artifact`.
    @Attribute(.externalStorage) var audioData: Data? = nil
    @Attribute(.externalStorage) var thumbnailData: Data? = nil
    
    // MARK: - Legacy Metadata (Deprecated)
    /// LEGACY: Kind of media (photo/music/audio). New data should use Artifact.kind instead.
    /// Kept for backward compatibility with existing records.
    var type: String = "photo"
    
    /// LEGACY: URL (for links/music). Kept for backward compatibility; new data via Artifact.metadata["url"].
    var url: String? = nil
    
    /// LEGACY: Title. Kept for backward compatibility; new data via Artifact.title.
    var title: String? = nil
    
    /// LEGACY: Caption/transcript. Kept for backward compatibility; new data via Artifact.textContent or summary.
    var caption: String? = nil
    
    /// LEGACY: Album name for music. Kept for backward compatibility; new data via Artifact.metadata["albumName"].
    var albumName: String? = nil
    
    /// LEGACY: Artwork URL. Kept for backward compatibility; new data via Artifact.metadata["artworkURL"].
    var artworkURLString: String? = nil
    
    /// LEGACY: Display sort index. Kept for backward compatibility; not used for new data.
    var sortIndex: Int = 0
    
    /// LEGACY: Location coordinates. Kept for backward compatibility; new data via Artifact.metadata["latitude"/"longitude"].
    var latitude: Double? = nil
    var longitude: Double? = nil
    
    /// LEGACY: Location name. Kept for backward compatibility; new data via Artifact.metadata["location"].
    var locationName: String? = nil
    
    /// LEGACY: AI description. Should not be used; any analysis should go through proper Reflection/Analysis APIs.
    var aiDescription: String? = nil
    
    /// LEGACY: Capture timestamp. Kept for backward compatibility; new data via Artifact.createdAt.
    var capturedAt: Date? = nil
    init() {}
}
