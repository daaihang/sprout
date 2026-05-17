import SwiftUI

struct LinkInputView: View {
    @Binding var urlText: String
    @Binding var noteText: String
    let metadata: LinkMetadataResult?
    let isFetching: Bool
    let onURLChange: (String) -> Void

    var body: some View {
        TextField("capture.attachment.url", text: $urlText)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .onChange(of: urlText) { _, newValue in
                onURLChange(newValue)
            }

        if isFetching {
            HStack(spacing: 8) {
                ProgressView()
                Text("capture.link.fetching")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let metadata {
            LinkMetadataPreview(metadata: metadata)
        }

        TextField("capture.prompt.link", text: $noteText, axis: .vertical)
            .lineLimit(2...5)
    }
}

struct AutoDetectedLinkPreview: View {
    let metadata: LinkMetadataResult?
    let isFetching: Bool

    var body: some View {
        if let metadata {
            VStack(alignment: .leading, spacing: 6) {
                Label("capture.link.autoDetected", systemImage: "link.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(metadata.title ?? metadata.url)
                    .font(.caption)
                    .lineLimit(2)
                Text(metadata.url)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        } else if isFetching {
            HStack(spacing: 8) {
                ProgressView()
                Text("capture.link.fetching")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LinkMetadataPreview: View {
    let metadata: LinkMetadataResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let imageData = metadata.imageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            if let title = metadata.title {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            if let summary = metadata.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let site = metadata.siteName {
                Text(site)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
