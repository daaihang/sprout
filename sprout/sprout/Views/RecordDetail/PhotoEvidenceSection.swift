import SwiftUI
import UIKit

/// Dedicated view for displaying photo evidence in a record's detail page.
/// Extracted from RecordDetailView to improve maintainability and reusability.
@MainActor
struct PhotoEvidenceSection: View {
    @Environment(AppLocalization.self) private var localization
    
    let artifacts: [Artifact]
    
    var body: some View {
        let photoArtifacts = artifacts.filter { $0.kind == .photo }
        
        if !photoArtifacts.isEmpty {
            let images: [UIImage] = photoArtifacts.compactMap { artifact in
                (artifact.binaryPayload ?? artifact.previewPayload).flatMap(UIImage.init(data:))
            }
            
            let leadArtifact = photoArtifacts.first
            
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "photo.on.rectangle.angled", title: localization.string("detail.section.photos", default: "Photos"))
                
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
                let photoLoc = leadArtifact?.metadata["locationName"] ?? nonEmpty(leadArtifact?.title)
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
