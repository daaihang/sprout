import SwiftUI

struct ArtifactStagingListView: View {
    @Binding var drafts: [CaptureArtifactDraft]

    var body: some View {
        Section {
            if drafts.isEmpty {
                Text("capture.content.empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(drafts.indices, id: \.self) { index in
                    HStack(alignment: .top) {
                        Label(drafts[index].captureSummary, systemImage: drafts[index].captureIconName)
                            .font(.subheadline)
                            .lineLimit(3)
                        Spacer()
                        Button(role: .destructive) {
                            drafts.remove(at: index)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        } header: {
            Text("capture.section.addedContent")
        } footer: {
            Text("capture.content.footer")
        }
    }
}

struct CurrentArtifactPreview: View {
    let drafts: [CaptureArtifactDraft]

    var body: some View {
        if !drafts.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("capture.content.current")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(drafts.indices, id: \.self) { index in
                    Label(drafts[index].captureSummary, systemImage: drafts[index].captureIconName)
                        .font(.caption)
                        .lineLimit(2)
                }
            }
        }
    }
}

struct ContextCandidateListView: View {
    @Binding var candidates: [ContextCandidate]
    let isCollecting: Bool
    let onRefresh: () -> Void

    var body: some View {
        Section {
            Button {
                onRefresh()
            } label: {
                Label(isCollecting ? String(localized: "capture.context.collecting") : String(localized: "capture.context.collectPreview"), systemImage: "arrow.clockwise")
            }
            .disabled(isCollecting)

            if isCollecting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("capture.context.collecting")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if candidates.isEmpty {
                Text("capture.context.previewEmpty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(candidates) { candidate in
                    Toggle(isOn: contextSelectionBinding(for: candidate.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(candidate.draft.captureSummary, systemImage: candidate.draft.captureIconName)
                                .font(.caption)
                                .lineLimit(2)
                            Text(candidate.capturedAt.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        } header: {
            Text("capture.section.contextPreview")
        } footer: {
            Text("capture.context.previewFooter")
        }
    }

    private func contextSelectionBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: {
                candidates.first(where: { $0.id == id })?.isSelected ?? false
            },
            set: { isSelected in
                guard let index = candidates.firstIndex(where: { $0.id == id }) else { return }
                candidates[index].isSelected = isSelected
            }
        )
    }
}

struct ContextCandidate: Identifiable, Hashable {
    let id = UUID()
    var draft: CaptureArtifactDraft
    var capturedAt: Date
    var isSelected: Bool
}

extension CaptureArtifactDraft {
    var captureIconName: String {
        switch self {
        case .text: return "text.alignleft"
        case .photo: return "photo"
        case .audio: return "waveform"
        case .video: return "video"
        case .location: return "mappin.and.ellipse"
        case .link: return "link"
        case .todo: return "checklist"
        case .weather: return "cloud.sun"
        case .music: return "music.note"
        }
    }
}
