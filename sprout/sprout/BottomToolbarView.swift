import SwiftUI

// MARK: - BottomCapsuleBar

struct BottomCapsuleBar: View {
    @Binding var isOpen: Bool

    // Callbacks
    var onAction: (ComposerActionType) -> Void = { _ in }
    var onRemoveAttachment: (ComposerAttachmentKey) -> Void = { _ in }
    var onSend: (String) -> Void = { _ in }

    // Current attachments — read-only display
    var attachments: ComposerAttachments = .init()

    // Voice recording service
    var speechRecognizer: SpeechRecognizer? = nil
    var onAudioCaptured: (Data?) -> Void = { _ in }

    // MARK: Internal state
    @State private var inputText: String = ""
    @FocusState private var inputFocused: Bool
    @Namespace private var morphSpace

    // Voice recording
    @State private var isVoiceRecording = false
    @State private var voiceLevels: [Float] = Array(repeating: 0.02, count: 24)
    @State private var levelTimer: Timer?
    @State private var pressStart: Date? = nil
    @State private var longPressTriggered = false

    private let sideSize:  CGFloat = 52
    private let pillH:     CGFloat = 52
    private let hPad:      CGFloat = 20
    private let cardHPad:  CGFloat = 10
    private let cardRadius: CGFloat = 28

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            if isOpen {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                Spacer()
                if #available(iOS 26.0, *) {
                    ios26Bar
                } else {
                    fallbackBar
                }
            }
            .padding(.bottom, 20)
        }
        .animation(.spring(duration: 0.45, bounce: 0.2), value: isOpen)
        .animation(.spring(duration: 0.35, bounce: 0.1), value: isVoiceRecording)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    // MARK: iOS 26 — liquid glass

    @available(iOS 26.0, *)
    private var ios26Bar: some View {
        ZStack(alignment: .bottom) {
            // Side buttons — only in collapsed state
            if !isOpen && !isVoiceRecording {
                HStack {
                    Button { onAction(.camera) } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: sideSize, height: sideSize)
                    }
                    .glassEffect(.regular, in: Circle())

                    Spacer()

                    Button { onAction(.addCard) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: sideSize, height: sideSize)
                    }
                    .glassEffect(.regular, in: Circle())
                }
                .padding(.horizontal, hPad)
                .transition(.opacity)
            }

            GlassEffectContainer {
                if isOpen {
                    let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let canSend = !trimmed.isEmpty || !attachments.isEmpty
                    VStack(spacing: 8) {
                        HStack {
                            Button { close() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, height: 32)
                            }
                            .glassEffect(.regular, in: Circle())

                            Spacer()

                            Button {
                                guard canSend else { return }
                                onSend(trimmed)
                                close()
                            } label: {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(canSend ? .white : .secondary)
                                    .frame(width: 32, height: 32)
                            }
                            .glassEffect(
                                canSend ? .regular.tint(Color.accentColor) : .regular,
                                in: Circle()
                            )
                            .disabled(!canSend)
                        }
                        .padding(.horizontal, cardHPad + 4)

                        cardInputContent
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
                            .matchedGeometryEffect(id: "bar", in: morphSpace)
                            .padding(.horizontal, cardHPad)
                    }
                    .onAppear { inputFocused = true }
                } else if isVoiceRecording {
                    voiceRecordingOverlay
                        .padding(.horizontal, hPad)
                        .transition(.scale(scale: 0.95, anchor: .bottom).combined(with: .opacity))
                } else {
                    pillButton
                        .glassEffect(.regular, in: Capsule())
                        .matchedGeometryEffect(id: "bar", in: morphSpace)
                        .padding(.horizontal, hPad + sideSize + 10)
                }
            }
        }
    }

    // MARK: Fallback — ultraThinMaterial (iOS 18 / 19)

    private var fallbackBar: some View {
        Group {
            if isOpen {
                let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                let canSend = !trimmed.isEmpty || !attachments.isEmpty
                VStack(spacing: 8) {
                    HStack {
                        Button { close() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .background(.regularMaterial, in: Circle())
                        }
                        Spacer()
                        Button {
                            guard canSend else { return }
                            onSend(trimmed)
                            close()
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(
                                    canSend
                                        ? AnyShapeStyle(Color.accentColor)
                                        : AnyShapeStyle(Color.secondary.opacity(0.3)),
                                    in: Circle()
                                )
                        }
                        .disabled(!canSend)
                    }
                    .padding(.horizontal, cardHPad + 4)

                    cardInputContent
                        .background(.ultraThinMaterial,
                                     in: RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                                .stroke(.white.opacity(0.25), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 8)
                        .padding(.horizontal, cardHPad)
                }
                .onAppear { inputFocused = true }
                .transition(.scale(scale: 0.92, anchor: .bottom).combined(with: .opacity))

            } else if isVoiceRecording {
                voiceRecordingOverlay
                    .padding(.horizontal, hPad)
                    .transition(.scale(scale: 0.95, anchor: .bottom).combined(with: .opacity))

            } else {
                HStack(spacing: 10) {
                    fallbackCircleBtn(icon: "camera.fill") { onAction(.camera) }

                    pillButton
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.08), radius: 12)

                    fallbackCircleBtn(icon: "plus") { onAction(.addCard) }
                }
                .padding(.horizontal, hPad)
                .transition(.scale(scale: 0.95, anchor: .bottom).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func fallbackCircleBtn(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: sideSize, height: sideSize)
        }
        .background(.ultraThinMaterial, in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 12)
    }

    // MARK: Pill button (shared tap + long-press logic)

    private var pillButton: some View {
        Text("点击输入  长按语音")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: pillH)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Start timing on first call
                        if pressStart == nil {
                            pressStart = Date()
                            longPressTriggered = false
                            // After 0.4 s, begin voice recording
                            Task {
                                try? await Task.sleep(for: .milliseconds(400))
                                guard pressStart != nil, !longPressTriggered else { return }
                                longPressTriggered = true
                                startVoiceMode()
                            }
                        }
                        // Cancel if dragged far left during recording
                        if isVoiceRecording && value.translation.width < -60 {
                            cancelVoice()
                        }
                    }
                    .onEnded { value in
                        let waRecording = isVoiceRecording
                        if waRecording {
                            if value.translation.width < -60 {
                                cancelVoice()
                            } else {
                                commitVoice()
                            }
                        } else if !longPressTriggered {
                            // Short tap → open composer
                            open()
                        }
                        pressStart = nil
                        longPressTriggered = false
                    }
            )
    }

    // MARK: Card input content (shared between iOS 26 and fallback)

    private var cardInputContent: some View {
        VStack(spacing: 0) {
            TextField("今天想记录什么？", text: $inputText, axis: .vertical)
                .font(.system(size: 16))
                .lineLimit(3...8)
                .focused($inputFocused)

            Divider()
                .padding(.vertical, 12)

            // Toolbar action buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    toolbarBtn("mic")        { startVoiceMode() }
                    toolbarBtn("photo")      { onAction(.photo) }
                    toolbarBtn("camera")     { onAction(.camera) }
                    toolbarBtn("location")   { onAction(.location) }
                    toolbarBtn("music.note") { onAction(.music) }
                    toolbarBtn("link")       { onAction(.link) }
                }
            }

            // Attachment chips (shown when attachments are present)
            if !attachments.isEmpty {
                Divider()
                    .padding(.top, 8)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let mood = attachments.mood {
                            AttachmentChip(prefix: mood.emoji, label: mood.label) {
                                onRemoveAttachment(.mood)
                            }
                        }
                        if !attachments.photos.isEmpty {
                            AttachmentChip(prefix: "📷", label: "\(attachments.photos.count)张照片") {
                                onRemoveAttachment(.photo)
                            }
                        }
                        if let loc = attachments.locationData {
                            AttachmentChip(prefix: "📍", label: loc.locationName.isEmpty ? "位置" : loc.locationName) {
                                onRemoveAttachment(.location)
                            }
                        }
                        if let music = attachments.music {
                            AttachmentChip(prefix: "🎵", label: music.trackName.isEmpty ? "音乐" : music.trackName) {
                                onRemoveAttachment(.music)
                            }
                        }
                        if attachments.todos != nil {
                            AttachmentChip(prefix: "✅", label: "待办") {
                                onRemoveAttachment(.todo)
                            }
                        }
                        if attachments.audioData != nil {
                            AttachmentChip(prefix: "🎙", label: "语音") {
                                onRemoveAttachment(.audio)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 8)
                }
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private func toolbarBtn(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
        }
    }

    // MARK: Voice recording overlay

    private var voiceRecordingOverlay: some View {
        VStack(spacing: 12) {
            // Waveform bars
            HStack(alignment: .center, spacing: 3) {
                ForEach(0 ..< voiceLevels.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red.opacity(0.8))
                        .frame(width: 4, height: CGFloat(voiceLevels[i]) * 44 + 4)
                        .animation(.linear(duration: 0.05), value: voiceLevels[i])
                }
            }
            .frame(height: 52)

            Text(durationString)
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundStyle(.primary)

            HStack {
                Text("← 左滑取消")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("松开发送")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    private var durationString: String {
        let t = Int(speechRecognizer?.recordingDuration ?? 0)
        return String(format: "%02d:%02d", t / 60, t % 60)
    }

    // MARK: Voice helpers

    private func startVoiceMode() {
        guard let sr = speechRecognizer else { return }
        guard !isVoiceRecording else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(duration: 0.35, bounce: 0.1)) { isVoiceRecording = true }
        sr.startRecording()
        // Start waveform update timer
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [self] _ in
            Task { @MainActor in
                updateVoiceLevels()
            }
        }
    }

    private func cancelVoice() {
        guard isVoiceRecording else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        speechRecognizer?.stopRecording()
        stopLevelTimer()
        withAnimation(.spring(duration: 0.3)) { isVoiceRecording = false }
        voiceLevels = Array(repeating: 0.02, count: 24)
    }

    private func commitVoice() {
        guard isVoiceRecording, let sr = speechRecognizer else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        sr.stopRecording()
        stopLevelTimer()
        let text  = sr.recognizedText
        let audio = sr.audioData
        withAnimation(.spring(duration: 0.3)) { isVoiceRecording = false }
        voiceLevels = Array(repeating: 0.02, count: 24)
        // Populate text field and open composer
        if !text.isEmpty { inputText = text }
        onAudioCaptured(audio)
        open()
    }

    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    @MainActor
    private func updateVoiceLevels() {
        let level = speechRecognizer?.audioLevel ?? 0
        var levels = voiceLevels
        levels.removeFirst()
        levels.append(level)
        voiceLevels = levels
    }

    // MARK: Open / Close

    private func open() {
        withAnimation(.spring(duration: 0.45, bounce: 0.2)) { isOpen = true }
    }

    private func close() {
        inputFocused = false
        inputText    = ""
        withAnimation(.spring(duration: 0.4, bounce: 0.1)) { isOpen = false }
    }
}

// MARK: - AttachmentChip

private struct AttachmentChip: View {
    let prefix: String
    let label:  String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(prefix + " " + label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.78, green: 0.91, blue: 0.97), location: 0),
                .init(color: Color(red: 0.92, green: 0.96, blue: 0.92), location: 1),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        BottomCapsuleBar(isOpen: .constant(false))
    }
}
