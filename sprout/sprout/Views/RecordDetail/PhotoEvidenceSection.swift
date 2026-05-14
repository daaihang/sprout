import SwiftUI
import UIKit

/// Dedicated view for displaying photo evidence in a record's detail page.
/// Extracted from RecordDetailView to improve maintainability and reusability.
@MainActor
struct PhotoEvidenceSection: View {
    @Environment(AppLocalization.self) private var localization
    
    let artifacts: [Artifact]
    let record: Record
    let mediaCards: [MediaCard]
    
    var body: some View {
        let photoArtifacts = artifacts.filter { $0.kind == .photo }
        let hasArtifacts = !photoArtifacts.isEmpty
        let hasLegacy = !mediaCards.isEmpty
        
        if hasArtifacts || hasLegacy {
            let photoPayloads = hasArtifacts ? photoArtifacts.flatMap { artifact in
                mediaCards.filter { $0.id == artifact.id }
            } : mediaCards
            
            let images: [UIImage] = photoPayloads.compactMap { m in
                m.imageData.flatMap(UIImage.init(data:))
            }
            
            let leadArtifact = photoArtifacts.first
            
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "photo.on.rectangle.angled", title: localization.t("detail.section.photos", "Photos"))
                
                // Photo gallery
                if images.isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: "photo").font(.largeTitle)
                                .foregroundStyle(.secondary.opacity(0.4))
                        )
                } else if images.count == 1 {
                    Image(uiImage: images[0])
                        .resizable().aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity).frame(height: 260).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    TabView {
                        ForEach(images.indices, id: \.self) { idx in
                            Image(uiImage: images[idx])
                                .resizable().aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity).clipped()
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Location metadata
                let photoLoc = leadArtifact?.metadata["locationName"] ?? photoPayloads.first?.locationName ?? record.location
                if let loc = photoLoc, !loc.isEmpty {
                    Label(loc, systemImage: "location.fill")
                        .font(.caption).foregroundStyle(.secondary)
                }
                
                // Summary
                if let summary = nonEmpty(leadArtifact?.summary) {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Legacy caption fallback
                if let legacyCaption = photoPayloads.first?.caption, !legacyCaption.isEmpty, leadArtifact?.summary == nil {
                    Text(legacyCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .detailCard()
        }
    }
}

// MARK: - Helper

private func nonEmpty(_ str: String?) -> String? {
    guard let str = str, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return str
}
