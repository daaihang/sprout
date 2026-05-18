import PhotosUI
import SwiftUI
import UIKit

struct UnifiedCaptureSeed: Identifiable, Equatable {
    let id = UUID()
    var voiceResult: QuickVoiceCaptureResult?
    var opensCameraOnAppear = false

    static var empty: UnifiedCaptureSeed {
        UnifiedCaptureSeed()
    }

    static var photoCapture: UnifiedCaptureSeed {
        UnifiedCaptureSeed(opensCameraOnAppear: true)
    }

    static func voice(_ result: QuickVoiceCaptureResult) -> UnifiedCaptureSeed {
        UnifiedCaptureSeed(voiceResult: result)
    }
}

struct UnifiedCaptureComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.memoryRepository) private var memoryRepository

    let seed: UnifiedCaptureSeed
    let onSaved: () -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var mood = ""
    @State private var inputContext = ""
    @State private var stagedArtifactDrafts: [CaptureArtifactDraft] = []
    @State private var contextCandidates: [ContextCandidate] = []
    @State private var isCollectingContext = false
    @State private var hasLoadedInitialContext = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isPresentingCamera = false
    @State private var isProcessingPhoto = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isBodyFocused: Bool

    private var selectedContextDrafts: [CaptureArtifactDraft] {
        contextCandidates.filter(\.isSelected).map(\.draft)
    }

    private var primaryArtifactDrafts: [CaptureArtifactDraft] {
        var drafts = stagedArtifactDrafts
        if let text = bodyText.trimmedOrNil {
            drafts.insert(.text(title: title.trimmedOrNil, body: text), at: 0)
        }
        return drafts
    }

    private var allArtifactDrafts: [CaptureArtifactDraft] {
        primaryArtifactDrafts + selectedContextDrafts
    }

    private var canSave: Bool {
        !isSaving && !isProcessingPhoto && !primaryArtifactDrafts.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                primarySection
                addContentSection
                artifactSection
                contextSection
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("capture.nav.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isPresentingCamera) {
                UnifiedCameraCaptureView { image in
                    Task { await addCameraImage(image) }
                }
                .ignoresSafeArea()
            }
            .task {
                applySeedIfNeeded()
                await loadInitialAutoContextIfNeeded()
                if seed.opensCameraOnAppear {
                    isBodyFocused = false
                    if !isPresentingCamera {
                        isPresentingCamera = true
                    }
                } else {
                    isBodyFocused = seed.voiceResult == nil
                }
            }
            .onChange(of: selectedPhotoItem) { _, item in
                Task { await addPhotoItem(item) }
            }
        }
    }

    private var primarySection: some View {
        Section("capture.section.capture") {
            TextField("capture.field.title", text: $title)
            TextField("quickCapture.text.placeholder", text: $bodyText, axis: .vertical)
                .lineLimit(5...12)
                .focused($isBodyFocused)
            TextField("capture.field.mood", text: $mood)
            TextField("capture.field.context", text: $inputContext, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    private var addContentSection: some View {
        Section {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("capture.photo.select", systemImage: "photo")
            }
            .disabled(isProcessingPhoto)

            Button {
                isPresentingCamera = true
            } label: {
                Label("quickCapture.photo", systemImage: "camera.fill")
            }
            .disabled(isProcessingPhoto)
        } header: {
            Text("capture.action.addContent")
        }
    }

    private var artifactSection: some View {
        Section {
            if isProcessingPhoto {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("capture.photo.analyzing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if primaryArtifactDrafts.isEmpty {
                Text("capture.content.empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stagedArtifactDrafts.indices, id: \.self) { index in
                    HStack(alignment: .top) {
                        Label(stagedArtifactDrafts[index].captureSummary, systemImage: stagedArtifactDrafts[index].captureIconName)
                            .font(.subheadline)
                            .lineLimit(3)
                        Spacer()
                        Button(role: .destructive) {
                            stagedArtifactDrafts.remove(at: index)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                if let text = bodyText.trimmedOrNil {
                    Label(
                        CaptureArtifactDraft.text(title: title.trimmedOrNil, body: text).captureSummary,
                        systemImage: "text.alignleft"
                    )
                    .font(.subheadline)
                    .lineLimit(3)
                }
            }
        } header: {
            Text("capture.section.addedContent")
        } footer: {
            Text("capture.content.footer")
        }
    }

    private var contextSection: some View {
        Section {
            Button {
                Task { await refreshAutoContext() }
            } label: {
                Label(isCollectingContext ? String(localized: "capture.context.collecting") : String(localized: "capture.context.collectPreview"), systemImage: "arrow.clockwise")
            }
            .disabled(isCollectingContext)

            if isCollectingContext {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("capture.context.collecting")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if contextCandidates.isEmpty {
                Text("capture.context.previewEmpty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(contextCandidates) { candidate in
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

    private func artifactChip(_ draft: CaptureArtifactDraft, removable: Bool = true, onRemove: (() -> Void)? = nil) -> some View {
        HStack(spacing: 8) {
            Label(draft.captureSummary, systemImage: draft.captureIconName)
                .font(.caption)
                .lineLimit(2)
            Spacer()
            if removable, let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func composerCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func contextSelectionBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: {
                contextCandidates.first(where: { $0.id == id })?.isSelected ?? false
            },
            set: { isSelected in
                guard let index = contextCandidates.firstIndex(where: { $0.id == id }) else { return }
                contextCandidates[index].isSelected = isSelected
            }
        )
    }

    @MainActor
    private func applySeedIfNeeded() {
        guard let voice = seed.voiceResult, stagedArtifactDrafts.isEmpty, bodyText.isEmpty else { return }
        let transcript = voice.transcription.trimmedOrNil
        bodyText = transcript ?? ""
        title = transcript?.firstMeaningfulLine ?? String(localized: "quickCapture.voice.defaultTitle")
        stagedArtifactDrafts.append(.audio(
            title: String(localized: "quickCapture.voice.defaultTitle"),
            summary: transcript ?? String(localized: "quickCapture.voice.defaultSummary"),
            filename: voice.filename,
            audioData: voice.audioData,
            transcriptionText: transcript ?? ""
        ))
    }

    private func loadInitialAutoContextIfNeeded() async {
        guard !hasLoadedInitialContext else { return }
        hasLoadedInitialContext = true
        await refreshAutoContext()
    }

    @MainActor
    private func refreshAutoContext() async {
        guard !isCollectingContext else { return }
        isCollectingContext = true
        defer { isCollectingContext = false }
        let collectedAt = Date.now
        let drafts = await ContextAutoCollector().collectContextDrafts()
        contextCandidates = drafts.map { draft in
            ContextCandidate(draft: draft, capturedAt: collectedAt, isSelected: true)
        }
    }

    @MainActor
    private func addPhotoItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isProcessingPhoto = true
        defer {
            isProcessingPhoto = false
            selectedPhotoItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            await addPhotoData(data, filename: "photo_\(Int(Date().timeIntervalSince1970)).jpg")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func addCameraImage(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.86) else { return }
        isProcessingPhoto = true
        defer { isProcessingPhoto = false }
        await addPhotoData(data, filename: "camera_\(Int(Date().timeIntervalSince1970)).jpg")
    }

    @MainActor
    private func addPhotoData(_ data: Data, filename: String) async {
        let result = await PhotoArtifactProcessor().process(imageData: data, filename: filename)
        let summary = result.summary.trimmedOrNil ?? String(localized: "quickCapture.photo.defaultSummary")
        let resolvedTitle = result.title.trimmedOrNil ?? String(localized: "quickCapture.photo.defaultTitle")
        stagedArtifactDrafts.append(.photo(
            title: resolvedTitle,
            summary: summary,
            filename: filename,
            imageData: data,
            thumbnailData: result.thumbnailData,
            ocrText: result.ocrText,
            photoMetadata: result.metadata
        ))
    }

    @MainActor
    private func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let rawText = bodyText.trimmedOrNil
                ?? primaryArtifactDrafts.map(\.captureSummary).joined(separator: "\n").trimmedOrNil
                ?? "Untitled Memory"
            let draft = MemoryCaptureDraft(
                title: title.trimmedOrNil ?? rawText.firstMeaningfulLine,
                rawText: rawText,
                mood: mood.trimmedOrNil,
                inputContext: inputContext.trimmedOrNil,
                captureSource: resolvedCaptureSource,
                artifacts: allArtifactDrafts
            )
            _ = try await CaptureOrchestrator(memoryRepository: memoryRepository).capture(draft: draft)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var resolvedCaptureSource: CaptureSource {
        if seed.voiceResult != nil {
            return .audio
        }
        if primaryArtifactDrafts.count == 1, case .photo = primaryArtifactDrafts[0] {
            return .photo
        }
        return .composer
    }
}

private struct UnifiedCameraCaptureView: UIViewControllerRepresentable {
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
