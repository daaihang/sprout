import SwiftUI
import PhotosUI
import AVFoundation

struct CaptureComposerView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: CaptureInputType = .text
    @State private var title = ""
    @State private var bodyText = ""
    @State private var mood = ""
    @State private var inputContext = ""
    @State private var attachmentValue = ""
    @State private var secondaryValue = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedStatusMessage: String?

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var selectedPhotoThumbnail: Data?
    @State private var photoFilename = ""
    @State private var audioRecorder = AudioRecorderModel()

    var onSaved: (() -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Everything saved here is local-first. This is the first stable path into the new memory stack.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Capture") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(CaptureInputType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    TextField("Title", text: $title)

                    switch selectedType {
                    case .photo:
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            if let selectedPhotoData {
                                if let uiImage = UIImage(data: selectedPhotoData),
                                   let thumbnailData = uiImage.preparingThumbnail(of: CGSize(width: 200, height: 200))?.jpegData(compressionQuality: 0.7) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .cornerRadius(8)
                                }
                                Text("Photo selected").foregroundStyle(.secondary)
                            } else {
                                Label("Select Photo", systemImage: "photo")
                            }
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedPhotoData = data
                                    if let uiImage = UIImage(data: data),
                                       let thumbnail = uiImage.preparingThumbnail(of: CGSize(width: 200, height: 200)) {
                                        selectedPhotoThumbnail = thumbnail.jpegData(compressionQuality: 0.7)
                                    }
                                    photoFilename = "photo_\(Date().timeIntervalSince1970).jpg"
                                }
                            }
                        }
                        TextField("Photo note", text: $bodyText, axis: .vertical)
                            .lineLimit(2...5)

                    case .audio:
                        VStack(spacing: 12) {
                            if audioRecorder.isRecording {
                                HStack {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 12, height: 12)
                                        .opacity(audioRecorder.recordingDuration > 0 ? 1 : 0.5)
                                    Text("Recording... \(Int(audioRecorder.recordingDuration))s")
                                        .font(.headline)
                                    Spacer()
                                    Button(audioRecorder.isRecording ? "Stop" : "Start") {
                                        audioRecorder.toggleRecording()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                }
                            } else {
                                Button {
                                    audioRecorder.toggleRecording()
                                } label: {
                                    Label(
                                        audioRecorder.recordedAudioURL != nil ? "Re-record" : "Start Recording",
                                        systemImage: "mic.fill"
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            if let url = audioRecorder.recordedAudioURL {
                                HStack {
                                    Image(systemName: "waveform")
                                        .foregroundStyle(.secondary)
                                    Text(url.lastPathComponent)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        TextField("Audio note", text: $bodyText, axis: .vertical)
                            .lineLimit(2...5)

                    default:
                        TextField(selectedType.primaryPrompt, text: $bodyText, axis: .vertical)
                            .lineLimit(selectedType == .text ? 4...10 : 2...5)
                    }

                    if let attachmentPrompt = selectedType.attachmentPrompt, selectedType != .photo && selectedType != .audio {
                        TextField(attachmentPrompt, text: $attachmentValue)
                    }
                    if let secondaryPrompt = selectedType.secondaryPrompt, selectedType != .audio {
                        TextField(secondaryPrompt, text: $secondaryValue)
                    }
                }

                Section("Context") {
                    TextField("Mood", text: $mood)
                    TextField("Input Context", text: $inputContext, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                if let savedStatusMessage {
                    Section {
                        Text(savedStatusMessage)
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("New Memory")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || !canSave)
                }
            }
        }
    }

    private var normalizedTitle: String? {
        title.trimmedOrNil ?? bodyText.firstMeaningfulLine
    }

    private var normalizedCaptureText: String? {
        bodyText.trimmedOrNil ?? title.trimmedOrNil
    }

    private var canSave: Bool {
        !artifactDrafts.isEmpty
    }

    private var artifactDrafts: [CaptureArtifactDraft] {
        switch selectedType {
        case .text:
            guard let rawText = normalizedCaptureText else { return [] }
            return [.text(title: normalizedTitle, body: rawText)]
        case .photo:
            let summary = bodyText.trimmedOrNil ?? title.trimmedOrNil ?? "Photo capture"
            guard let filename = photoFilename.trimmedOrNil else { return [] }
            return [.photo(title: normalizedTitle, summary: summary, filename: filename, imageData: selectedPhotoData, thumbnailData: selectedPhotoThumbnail)]
        case .audio:
            let summary = bodyText.trimmedOrNil ?? title.trimmedOrNil ?? "Audio capture"
            guard let filename = audioRecorder.recordedFilename else { return [] }
            return [.audio(title: normalizedTitle, summary: summary, filename: filename, audioData: audioRecorder.recordedAudioData)]
        case .location:
            guard bodyText.trimmedOrNil != nil || title.trimmedOrNil != nil || attachmentValue.trimmedOrNil != nil || secondaryValue.trimmedOrNil != nil else {
                return []
            }
            let latitude = Double(attachmentValue.trimmingCharacters(in: .whitespacesAndNewlines))
            let longitude = Double(secondaryValue.trimmingCharacters(in: .whitespacesAndNewlines))
            return [.location(title: normalizedTitle, summary: bodyText.trimmedOrNil ?? title.trimmedOrNil ?? "Location capture", latitude: latitude, longitude: longitude)]
        case .link:
            guard let url = attachmentValue.trimmedOrNil else { return [] }
            return [.link(title: normalizedTitle, url: url, note: bodyText.trimmedOrNil)]
        case .todo:
            guard let title = normalizedTitle ?? bodyText.trimmedOrNil else { return [] }
            return [.todo(title: title, note: secondaryValue.trimmedOrNil ?? bodyText.trimmedOrNil)]
        }
    }

    private func save() async {
        guard !isSaving, canSave else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let rawText = normalizedCaptureText
                ?? artifactDrafts.map(\.captureSummary).joined(separator: "\n").trimmedOrNil
                ?? title.trimmedOrNil
                ?? "Untitled Memory"
            let draft = MemoryCaptureDraft(
                title: normalizedTitle,
                rawText: rawText,
                mood: mood.trimmedOrNil,
                inputContext: inputContext.trimmedOrNil,
                captureSource: selectedType.captureSource,
                artifacts: artifactDrafts
            )
            let memory = try await memoryRepository.createMemory(from: draft)
            savedStatusMessage = memory.pipelineStatus?.userLabel ?? "Saved locally"
            errorMessage = nil
            Task {
                do {
                    try await memoryRepository.refreshMemoryPipeline(recordID: memory.record.id)
                } catch {
                    // The memory is already persisted locally. Failure is surfaced from detail/debug surfaces.
                }
            }
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            savedStatusMessage = nil
        }
    }
}

private enum CaptureInputType: String, CaseIterable, Identifiable {
    case text
    case photo
    case audio
    case location
    case link
    case todo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: return "Text"
        case .photo: return "Photo"
        case .audio: return "Audio"
        case .location: return "Location"
        case .link: return "Link"
        case .todo: return "Todo"
        }
    }

    var primaryPrompt: String {
        switch self {
        case .text: return "What happened?"
        case .photo: return "Photo note"
        case .audio: return "Audio note"
        case .location: return "Place note"
        case .link: return "Link note"
        case .todo: return "Todo detail"
        }
    }

    var attachmentPrompt: String? {
        switch self {
        case .photo: return "Filename"
        case .audio: return "Filename"
        case .location: return "Latitude"
        case .link: return "URL"
        case .text, .todo: return nil
        }
    }

    var secondaryPrompt: String? {
        switch self {
        case .location: return "Longitude"
        case .todo: return "Optional note"
        case .text, .photo, .audio, .link: return nil
        }
    }

    var captureSource: CaptureSource {
        switch self {
        case .text, .link, .todo, .location:
            return .composer
        case .photo:
            return .photo
        case .audio:
            return .audio
        }
    }
}

@MainActor
final class AudioRecorderModel: ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private let audioSession = AVAudioSession()

    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordedAudioURL: URL?
    @Published var recordedAudioData: Data?

    var recordedFilename: String? {
        recordedAudioURL?.lastPathComponent
    }

    init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        let filename = "audio_\(Date().timeIntervalSince1970).m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordingDuration = 0

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.recordingDuration += 0.1
                }
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        isRecording = false

        if let url = audioRecorder?.url {
            recordedAudioURL = url
            recordedAudioData = try? Data(contentsOf: url)
        }
    }
}
