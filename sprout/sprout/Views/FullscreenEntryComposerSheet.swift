import SwiftUI
import PhotosUI

struct FullscreenEntryComposerSheet: View {
    @Environment(AppLocalization.self) private var localization
    @Binding var text: String
    @Binding var attachments: ComposerAttachments

    var speechRecognizer: SpeechRecognizer
    var musicService: MusicService
    let onAction: (ComposerActionType) -> Void
    let onRemoveAttachment: (ComposerAttachmentKey) -> Void
    let onSubmit: (String) -> Void
    let onClose: () -> Void

    @FocusState private var inputFocused: Bool
    @State private var showCameraSheet = false
    @State private var showPhotosPicker = false
    @State private var showMusicSheet = false
    @State private var showLocationSheet = false
    @State private var showPeopleSheet = false
    @State private var showVoiceSheet = false
    @State private var pendingPhotoItems: [PhotosPickerItem] = []
    @State private var pendingMusicData = MusicCardData()
    @State private var pendingLocationData = MapCardData()

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedText.isEmpty || !attachments.isEmpty
    }

    private var captureSummaryTitle: String {
        var pieces: [String] = []
        if !trimmedText.isEmpty {
            pieces.append("Shell note")
        }
        if attachments.hasArtifacts {
            pieces.append(attachments.artifactCountLabel)
        }
        return pieces.isEmpty ? "Build this capture from text and artifacts." : pieces.joined(separator: " + ")
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Capture Bundle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(captureSummaryTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("One capture event creates a shell note and can bundle multiple artifacts.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    TextEditor(text: $text)
                        .font(.system(size: 18))
                        .frame(minHeight: 240)
                        .scrollContentBackground(.hidden)
                        .focused($inputFocused)

                    if !attachments.isEmpty {
                        artifactBundleSection
                    } else if !trimmedText.isEmpty {
                        shellOnlyHint
                    }
                }
                .padding(20)
            }
            .toolbarRole(.editor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .accessibilityLabel(t("toolbar.action.minimize", "Return to Compact Capture"))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard canSubmit else { return }
                        onSubmit(trimmedText)
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .disabled(!canSubmit)
                    .accessibilityLabel(t("common.done", "Done"))
                }

                ToolbarItem(placement: .keyboard) {
                    keyboardAccessoryToolbar
                }
            }
        }
        .presentationDragIndicator(.hidden)
        .onAppear {
            inputFocused = true
        }
        .fullScreenCover(isPresented: $showCameraSheet) {
            CameraView { image in
                attachments.photos.append(image)
            }
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $pendingPhotoItems,
            maxSelectionCount: 9,
            matching: .images
        )
        .sheet(isPresented: $showMusicSheet) {
            MusicCardSheet(data: $pendingMusicData, musicService: musicService)
                .onDisappear {
                    if !pendingMusicData.trackName.isEmpty {
                        attachments.music = pendingMusicData
                        pendingMusicData = MusicCardData()
                    }
                }
        }
        .sheet(isPresented: $showLocationSheet) {
            MapCardSheet(data: $pendingLocationData)
                .onDisappear {
                    if pendingLocationData.coordinate != nil {
                        attachments.locationData = pendingLocationData
                        pendingLocationData = MapCardData()
                    }
                }
        }
        .sheet(isPresented: $showPeopleSheet) {
            PeoplePickerSheet(selectedPeople: $attachments.people)
        }
        .sheet(isPresented: $showVoiceSheet) {
            VoiceCaptureSheet(speechRecognizer: speechRecognizer) { recognizedText, audioData in
                let trimmedRecognizedText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedRecognizedText.isEmpty {
                    text = trimmedRecognizedText
                }
                attachments.audioData = audioData
            }
        }
        .onChange(of: pendingPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                if !images.isEmpty {
                    attachments.photos.append(contentsOf: images)
                }
                pendingPhotoItems = []
            }
        }
    }

    private var artifactBundleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Artifacts in This Capture")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let mood = attachments.mood {
                        AttachmentChip(prefix: mood.emoji, label: mood.label) {
                            onRemoveAttachment(.mood)
                        }
                    }
                    if !attachments.photos.isEmpty {
                        AttachmentChip(prefix: "📷", label: t("toolbar.attachment.photos", "%d photos", attachments.photos.count)) {
                            onRemoveAttachment(.photo)
                        }
                    }
                    if let loc = attachments.locationData {
                        AttachmentChip(prefix: "📍", label: loc.locationName.isEmpty ? t("toolbar.attachment.location", "Location") : loc.locationName) {
                            onRemoveAttachment(.location)
                        }
                    }
                    if let music = attachments.music {
                        AttachmentChip(prefix: "🎵", label: music.trackName.isEmpty ? t("toolbar.attachment.music", "Music") : music.trackName) {
                            onRemoveAttachment(.music)
                        }
                    }
                    if !attachments.people.isEmpty {
                        AttachmentChip(prefix: "👥", label: t("toolbar.attachment.people", "%d people", attachments.people.count)) {
                            onRemoveAttachment(.people)
                        }
                    }
                    if attachments.todos != nil {
                        AttachmentChip(prefix: "✅", label: t("toolbar.attachment.todo", "To-Do")) {
                            onRemoveAttachment(.todo)
                        }
                    }
                    if attachments.audioData != nil {
                        AttachmentChip(prefix: "🎙", label: t("toolbar.attachment.voice", "Voice")) {
                            onRemoveAttachment(.audio)
                        }
                    }
                }
            }

            if !attachments.captureSummarySegments.isEmpty {
                Text(attachments.captureSummarySegments.joined(separator: " · "))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var shellOnlyHint: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("This capture currently has only the shell note. Add photo, voice, people, location, or music artifacts if needed.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var keyboardAccessoryToolbar: some View {
        ComposerActionToolbar(
            items: composerActionItems,
            style: .keyboard
        )
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }

    private var composerActionItems: [ComposerActionToolbarItem] {
        [
            .init(id: "voice", icon: "mic", accessibilityLabel: "Voice") {
                showVoiceSheet = true
            },
            .init(id: "photo", icon: "photo", accessibilityLabel: "Photo Library") {
                showPhotosPicker = true
            },
            .init(id: "camera", icon: "camera", accessibilityLabel: "Camera") {
                showCameraSheet = true
            },
            .init(id: "location", icon: "location", accessibilityLabel: "Location") {
                showLocationSheet = true
            },
            .init(id: "people", icon: "person.2", accessibilityLabel: "People") {
                showPeopleSheet = true
            },
            .init(id: "music", icon: "music.note", accessibilityLabel: "Music") {
                showMusicSheet = true
            },
            .init(id: "link", icon: "link", accessibilityLabel: "Link") {
                onAction(.link)
            }
        ]
    }
}

#Preview {
    FullscreenEntryComposerSheet(
        text: .constant(""),
        attachments: .constant(ComposerAttachments()),
        speechRecognizer: SpeechRecognizer(),
        musicService: MusicService(),
        onAction: { _ in },
        onRemoveAttachment: { _ in },
        onSubmit: { _ in },
        onClose: {}
    )
    .environment(AppLocalization.shared)
}
