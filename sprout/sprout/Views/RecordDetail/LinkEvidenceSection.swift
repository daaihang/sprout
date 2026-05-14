import SwiftUI

/// Dedicated view for displaying link evidence in a record's detail page.
/// Extracted from RecordDetailView to improve maintainability and reusability.
@MainActor
struct LinkEvidenceSection: View {
    @Environment(AppLocalization.self) private var localization
    
    let artifacts: [Artifact]
    
    var body: some View {
        if !artifacts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "link", title: localization.string("detail.section.links", default: "Links"))
                ForEach(artifacts, id: \.id) { artifact in
                    if let urlStr = artifact.metadata["url"] ?? nonEmpty(artifact.textContent),
                       let url = URL(string: urlStr) {
                        linkRow(title: nonEmpty(artifact.title) ?? urlStr, 
                                subtitle: nonEmpty(artifact.summary) ?? url.host ?? urlStr,
                                url: url)
                    }
                }
            }
            .detailCard()
        }
    }
    
    private func linkRow(title: String, subtitle: String, url: URL) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.1))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "safari.fill").font(.system(size: 18))
                        .foregroundStyle(Color.accentColor)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium)).lineLimit(1)
                Text(subtitle)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Link(destination: url) {
                Image(systemName: "arrow.up.right.square").foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Helper

private func nonEmpty(_ str: String?) -> String? {
    guard let str = str, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return str
}
