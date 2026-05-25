import SwiftUI
import UIKit

struct UnifiedAudioCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = AudioRecorderModel()

    let onAdd: (CaptureArtifactDraft, String) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if recorder.isRecording {
                    HStack(spacing: 8) {
                        Image(systemName: "record.circle.fill")
                            .foregroundStyle(.red)
                        Text(String(format: String(localized: "capture.voice.recordingSeconds.format"), Int(recorder.recordingDuration)))
                            .font(.subheadline.weight(.semibold))
                    }
                }

                if let failure = recorder.errorMessage {
                    Text(failure)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if recorder.isStopping || recorder.isTranscribing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(recorder.isTranscribing ? String(localized: "capture.audio.transcribing") : String(localized: "capture.audio.finalizing"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let transcript = resolvedTranscript {
                    ScrollView {
                        Text(transcript)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text("capture.voice.startAttachPrompt")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("capture.card.kind.audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        Task {
                            await recorder.cancelRecording()
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("capture.action.add") {
                        guard let output = recorder.recordedAudioData else { return }
                        let transcript = resolvedTranscript ?? ""
                        let filename = recorder.recordedFilename ?? "audio_\(Int(Date().timeIntervalSince1970)).caf"
                        let draft = CaptureArtifactDraft.audio(
                            title: nil,
                            summary: String(localized: "capture.voice.noteSummary"),
                            filename: filename,
                            audioData: output,
                            transcriptionText: transcript,
                            origin: .manual
                        )
                        onAdd(draft, transcript)
                        dismiss()
                    }
                    .disabled(recorder.recordedAudioData == nil || recorder.isBusy)
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        if recorder.isRecording {
                            Button("capture.audio.stop") {
                                Task { _ = await recorder.stopAndTranscribe() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        } else {
                            Button("capture.audio.record") {
                                Task { await recorder.startRecording() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(recorder.isBusy)
                        }
                        Spacer()
                        if recorder.recordedAudioData != nil {
                            Button("capture.action.retry") {
                                recorder.clearRecording()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    private var resolvedTranscript: String? {
        recorder.finalTranscription.trimmedOrNil ?? recorder.liveTranscription.trimmedOrNil
    }
}

struct UnifiedLinkCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var noteText = ""
    @State private var metadata: LinkMetadataResult?
    @State private var isFetching = false
    @State private var errorMessage: String?

    let onAdd: (CaptureArtifactDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("capture.card.kind.link") {
                    TextField("capture.field.url", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            Task { await fetchMetadata() }
                        }
                    TextField("capture.field.note", text: $noteText, axis: .vertical)
                        .lineLimit(2...5)
                }

                if isFetching {
                    Section {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("capture.link.loadingPreview")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let metadata {
                    Section("capture.section.preview") {
                        if let title = metadata.title?.trimmedOrNil {
                            Text(title).font(.subheadline.weight(.semibold))
                        }
                        if let summary = metadata.summary?.trimmedOrNil {
                            Text(summary).font(.footnote).foregroundStyle(.secondary)
                        }
                        Text(metadata.url).font(.caption).foregroundStyle(.tertiary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("capture.card.kind.link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("capture.action.add") {
                        onAdd(makeDraft())
                        dismiss()
                    }
                    .disabled(urlText.trimmedOrNil == nil)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("capture.link.refreshPreview") {
                        Task { await fetchMetadata() }
                    }
                    .disabled(urlText.trimmedOrNil == nil || isFetching)
                }
            }
        }
    }

    private func fetchMetadata() async {
        guard let normalizedURL = urlText.trimmedOrNil else { return }
        isFetching = true
        defer { isFetching = false }
        metadata = await LinkMetadataExtractor().extract(urlString: normalizedURL)
        errorMessage = metadata == nil ? String(localized: "capture.link.previewFailed") : nil
    }

    private func makeDraft() -> CaptureArtifactDraft {
        let url = metadata?.url.trimmedOrNil ?? urlText.trimmedOrNil ?? ""
        return .link(
            title: metadata?.title,
            url: url,
            note: noteText.trimmedOrNil,
            summary: metadata?.summary,
            metadata: metadata?.metadata ?? ["url": url],
            thumbnailData: metadata?.imageData,
            origin: .manual
        )
    }
}

struct UnifiedMusicCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [MusicCatalogSongCandidate] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let musicService = MusicContextService()
    let onAdd: (CaptureArtifactDraft) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await addNowPlaying() }
                    } label: {
                        Label("capture.music.addNowPlaying", systemImage: "music.note")
                    }

                    TextField("capture.music.searchSongs", text: $query)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await searchSongs() }
                        }

                    Button {
                        Task { await searchSongs() }
                    } label: {
                        Label(isSearching ? String(localized: "capture.action.searching") : String(localized: "capture.action.search"), systemImage: "magnifyingglass")
                    }
                    .disabled(isSearching || query.trimmedOrNil == nil)
                }

                if isSearching {
                    Section {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("capture.music.searchingCatalog")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !results.isEmpty {
                    Section("capture.section.results") {
                        ForEach(results) { song in
                            Button {
                                onAdd(song.toDraft(origin: .manual))
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(song.title)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(2)
                                    Text([song.artistName, song.albumTitle].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("capture.card.kind.music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func addNowPlaying() async {
        if let draft = await musicService.captureCurrentMusicItem(origin: .manual) {
            onAdd(draft)
            errorMessage = nil
            return
        }
        errorMessage = String(localized: "capture.music.noNowPlaying")
    }

    @MainActor
    private func searchSongs() async {
        guard let normalized = query.trimmedOrNil else { return }
        isSearching = true
        defer { isSearching = false }
        let songs = await musicService.searchSongs(query: normalized, limit: 20)
        results = songs
        errorMessage = songs.isEmpty ? String(localized: "capture.music.noSongsFound") : nil
    }
}

struct UnifiedTodoCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var note = ""
    let onAdd: (CaptureArtifactDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("capture.card.kind.todo") {
                    TextField("capture.field.title", text: $title)
                    TextField("capture.field.note", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("capture.card.kind.todo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("capture.action.add") {
                        guard let resolvedTitle = title.trimmedOrNil else { return }
                        onAdd(.todo(title: resolvedTitle, note: note.trimmedOrNil, origin: .manual))
                        dismiss()
                    }
                    .disabled(title.trimmedOrNil == nil)
                }
            }
        }
    }
}

struct UnifiedCameraCaptureView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onCapture: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
