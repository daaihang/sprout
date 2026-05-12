import SwiftUI
import Speech


// MARK: - BottomCapsuleBar

struct BottomCapsuleBar: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isOpen: Bool
    @Binding var inputText: String
    var focusRequestToken: Int = 0

    // Callbacks
    var onAction: (ComposerActionType) -> Void = { _ in }
    var onRemoveAttachment: (ComposerAttachmentKey) -> Void = { _ in }
    var onSend: (String) -> Void = { _ in }
    var onExpandToFullscreen: () -> Void = {}

    // Current attachments — read-only display
    var attachments: ComposerAttachments = .init()

    // Voice recording service
    var speechRecognizer: SpeechRecognizer? = nil
    var onAudioCaptured: (Data?) -> Void = { _ in }

    // MARK: Internal state
    @FocusState private var inputFocused: Bool
    @Namespace private var morphSpace
    
    // Voice recording
    @State private var voiceCaptureState: VoiceCaptureState = .idle
    @State private var voiceLevels: [Float] = Array(repeating: 0.02, count: 24)
    @State private var levelTimer: Timer?
    @State private var pressStart: Date? = nil
    @State private var pressToken = UUID()
    @State private var longPressTriggered = false
    @State private var isClosingComposer = false
    @State private var isPillPressed = false
    @State private var transcriptionContentHeight: CGFloat = 48

    // Drag gesture tracking
    @State private var dragOffset: CGSize = .zero
    @State private var activeDragTarget: VoiceDragTarget = .none

    private let sideSize:  CGFloat = 52
    private let pillH:     CGFloat = 52
    private let hPad:      CGFloat = 20
    private let cardHPad:  CGFloat = 10
    private let cardRadius: CGFloat = 28
    private let longPressDuration: TimeInterval = 0.4
    private let recordingCardSpacing: CGFloat = 18
    private let transcriptionMinHeight: CGFloat = 48
    private let transcriptionMaxHeight: CGFloat = 108
    private let fullscreenButtonSize: CGFloat = 40

    private enum VoiceCaptureState {
        case idle
        case holding
        case locked
    }

    private enum VoiceDragTarget {
        case none
        case cancel
        case lock
    }

    private var isVoiceRecording: Bool { voiceCaptureState != .idle }
    private var isVoiceHolding: Bool { voiceCaptureState == .holding }
    private var isVoiceLocked: Bool { voiceCaptureState == .locked }
    private var isDraggingToCancel: Bool { activeDragTarget == .cancel }
    private var isDraggingToContinue: Bool { activeDragTarget == .lock }
    private var pillSideInset: CGFloat { hPad + sideSize + 10 }
    private var trimmedInputText: String { inputText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSendComposer: Bool { !trimmedInputText.isEmpty || !attachments.isEmpty }
    private var showsComposerControls: Bool { isOpen }
    private var showsBackdropOverlay: Bool { isOpen || isVoiceRecording }
    private var recognizedText: String { speechRecognizer?.recognizedText ?? "" }
    private var trimmedRecognizedText: String { recognizedText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasRecognizedText: Bool { !trimmedRecognizedText.isEmpty }
    private var voiceBadgeOffset: CGSize {
        guard isVoiceHolding else { return .zero }
        return CGSize(
            width: dragOffset.width * 0.04,
            height: min(0, dragOffset.height * 0.03)
        )
    }
    private var voiceCardOffset: CGSize {
        guard isVoiceHolding else { return .zero }
        return CGSize(
            width: dragOffset.width * 0.07,
            height: min(0, dragOffset.height * 0.055)
        )
    }
    private var transcriptionPanelHeight: CGFloat {
        min(transcriptionMaxHeight, max(transcriptionMinHeight, transcriptionContentHeight))
    }
    private var composerBackdropTint: Color {
        colorScheme == .dark ? Color.black.opacity(0.28) : Color.white.opacity(0.22)
    }
    private var pillPressAnimation: Animation {
        .spring(duration: 0.22, bounce: 0.0)
    }
    private var sideButtonsTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9, anchor: .center).combined(with: .opacity),
            removal: .scale(scale: 0.92, anchor: .center).combined(with: .opacity)
        )
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                if showsBackdropOverlay {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(composerBackdropTint)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            guard isOpen else { return }
                            close()
                        }
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

                if !isOpen && !isVoiceLocked {
                    capsuleGestureSurface(containerWidth: geometry.size.width)
                        .padding(.bottom, 20)
                        .zIndex(3)
                }
            }
            .animation(.spring(duration: 0.45, bounce: 0.2), value: isOpen)
            .animation(.spring(duration: 0.45, bounce: 0.2), value: voiceCaptureState)
            .animation(.spring(duration: 0.32, bounce: 0.14), value: isClosingComposer)
            .onChange(of: focusRequestToken) { _, _ in
                guard isOpen else { return }
                Task { @MainActor in
                    inputFocused = true
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    // MARK: iOS 26 — liquid glass

    @available(iOS 26.0, *)
    private var ios26Bar: some View {
        ZStack(alignment: .bottom) {
            GlassEffectContainer {
                VStack(spacing: 8) {
                    if showsComposerControls {
                        ios26ComposerControlsRow
                    }

                    ZStack(alignment: .bottom) {
                        if !isOpen && !isVoiceRecording && !isClosingComposer {
                            HStack {
                                Button { HapticFeedback.light(); onAction(.camera) } label: {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .frame(width: sideSize, height: sideSize)
                                }
                                .glassEffect(.regular, in: Circle())

                                Spacer()

                                Button { HapticFeedback.light(); onAction(.addCard) } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .frame(width: sideSize, height: sideSize)
                                }
                                .glassEffect(.regular, in: Circle())
                            }
                            .padding(.horizontal, hPad)
                            .transition(sideButtonsTransition)
                        }

                        if isOpen {
                            composerInputCard
                        } else if isVoiceRecording {
                            voiceRecordingStack
                        } else {
                            pillButton
                                .frame(height: pillH)
                                .glassEffect(.regular, in: Capsule())
                                .matchedGeometryEffect(id: "bar", in: morphSpace)
                                .padding(.horizontal, pillSideInset)
                                .scaleEffect(isPillPressed ? 0.972 : 1.0, anchor: .center)
                                .animation(pillPressAnimation, value: isPillPressed)
                                .zIndex(2)
                        }
                    }
                }
            }
        }
    }

    // MARK: Fallback — ultraThinMaterial (iOS 18 / 19)

    private var fallbackBar: some View {
        Group {
            VStack(spacing: 8) {
                if showsComposerControls {
                    fallbackComposerControlsRow
                }

                ZStack(alignment: .bottom) {
                    if !isOpen && !isVoiceRecording && !isClosingComposer {
                        HStack(spacing: 10) {
                            fallbackCircleBtn(icon: "camera.fill") { HapticFeedback.light(); onAction(.camera) }
                            Spacer()
                            fallbackCircleBtn(icon: "plus") { HapticFeedback.light(); onAction(.addCard) }
                        }
                        .padding(.horizontal, hPad)
                        .transition(sideButtonsTransition)
                    }

                    if isOpen {
                        composerInputCard
                    } else if isVoiceRecording {
                        voiceRecordingStack
                    } else {
                        pillButton
                            .frame(height: pillH)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.08), radius: 12)
                            .matchedGeometryEffect(id: "bar", in: morphSpace)
                            .padding(.horizontal, pillSideInset)
                            .scaleEffect(isPillPressed ? 0.972 : 1.0, anchor: .center)
                            .animation(pillPressAnimation, value: isPillPressed)
                            .zIndex(2)
                    }
                }
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
        ZStack {
            if isVoiceRecording {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .background(Color.red.opacity(0.12), in: Circle())

                    Text(t("toolbar.recording", "Recording"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    Text(durationString)
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: pillH)
            } else {
                Text(t("toolbar.hint.tap_or_hold", "Tap to type  Hold to talk"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: pillH)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: pillH)
        .clipped()
        .contentShape(Capsule())
    }

    // MARK: Card input content (shared between iOS 26 and fallback)

    private var cardInputContent: some View {
        VStack(spacing: 0) {
            TextField(t("toolbar.input.placeholder", "What do you want to capture today?"), text: $inputText, axis: .vertical)
                .font(.system(size: 16))
                .lineLimit(3...8)
                .focused($inputFocused)

            Divider()
                .padding(.vertical, 12)

            HStack(spacing: 10) {
                ComposerActionToolbar(items: composerActionToolbarItems, style: .card)

                expandButton
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
                            AttachmentChip(
                                prefix: "👥",
                                label: t("toolbar.attachment.people", "%d people", attachments.people.count)
                            ) {
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
                    .padding(.horizontal, 2)
                    .padding(.top, 8)
                }
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private var expandButton: some View {
        Button {
            HapticFeedback.light()
            inputFocused = false
            onExpandToFullscreen()
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: fullscreenButtonSize, height: fullscreenButtonSize)
                .background(expandButtonBackground)
        }
        .accessibilityLabel(t("toolbar.action.fullscreen", "Open Fullscreen Composer"))
    }

    @ViewBuilder
    private var expandButtonBackground: some View {
        if #available(iOS 26.0, *) {
            Circle()
                .fill(.clear)
                .glassEffect(.regular, in: Circle())
        } else {
            Circle()
                .fill(.regularMaterial)
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
        }
    }

    @available(iOS 26.0, *)
    private var ios26ComposerControlsRow: some View {
        HStack {
            Button { HapticFeedback.light(); close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
            }
            .glassEffect(.regular, in: Circle())

            Spacer()

            Button {
                guard canSendComposer else { return }
                HapticFeedback.success()
                onSend(trimmedInputText)
                close()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(canSendComposer ? .white : .secondary)
                    .frame(width: 40, height: 40)
            }
            .glassEffect(
                canSendComposer ? .regular.tint(Color.accentColor) : .regular,
                in: Circle()
            )
            .disabled(!canSendComposer)
        }
        .padding(.horizontal, cardHPad + 4)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var fallbackComposerControlsRow: some View {
        HStack {
            Button { HapticFeedback.light(); close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(.regularMaterial, in: Circle())
            }
            Spacer()
            Button {
                guard canSendComposer else { return }
                HapticFeedback.success()
                onSend(trimmedInputText)
                close()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        canSendComposer
                            ? AnyShapeStyle(Color.accentColor)
                            : AnyShapeStyle(Color.secondary.opacity(0.3)),
                        in: Circle()
                    )
            }
            .disabled(!canSendComposer)
        }
        .padding(.horizontal, cardHPad + 4)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var composerInputCard: some View {
        composerCard {
            cardInputContent
        }
        .matchedGeometryEffect(id: "bar", in: morphSpace)
        .padding(.horizontal, cardHPad)
        .onAppear { inputFocused = true }
    }

    private var composerActionToolbarItems: [ComposerActionToolbarItem] {
        [
            .init(id: "voice", icon: "mic", accessibilityLabel: t("toolbar.action.voice", "Voice")) {
                HapticFeedback.light()
                startVoiceMode(initialState: .locked)
            },
            .init(id: "photo", icon: "photo", accessibilityLabel: "Photo Library") {
                HapticFeedback.light()
                onAction(.photo)
            },
            .init(id: "camera", icon: "camera", accessibilityLabel: "Camera") {
                HapticFeedback.light()
                onAction(.camera)
            },
            .init(id: "location", icon: "location", accessibilityLabel: "Location") {
                HapticFeedback.light()
                onAction(.location)
            },
            .init(id: "people", icon: "person.2", accessibilityLabel: "People") {
                HapticFeedback.light()
                onAction(.people)
            },
            .init(id: "music", icon: "music.note", accessibilityLabel: "Music") {
                HapticFeedback.light()
                onAction(.music)
            },
            .init(id: "link", icon: "link", accessibilityLabel: "Link") {
                HapticFeedback.light()
                onAction(.link)
            }
        ]
    }

    // MARK: Voice recording overlay

    private var voiceRecordingCardContent: some View {
        VStack(spacing: 12) {
            voiceTranscriptionPanel

            // Waveform bars
            HStack(alignment: .center, spacing: 3) {
                ForEach(0 ..< voiceLevels.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill((isVoiceLocked || isDraggingToContinue) ? Color.green.opacity(0.82) : Color.red.opacity(0.82))
                        .frame(width: 4, height: CGFloat(voiceLevels[i]) * 44 + 4)
                }
            }
            .frame(height: 52)
            .animation(.linear(duration: 0.08), value: voiceLevels)

            Text(durationString)
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundStyle(.primary)

            if isVoiceLocked {
                VStack(spacing: 10) {
                    Text(t("toolbar.voice.continuous", "Continuous recording"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        HapticFeedback.medium()
                        commitVoice()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text(t("toolbar.voice.stop", "Stop Recording"))
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Color.red, in: Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.15), value: isDraggingToCancel)
        .animation(.easeOut(duration: 0.15), value: isDraggingToContinue)
    }

    private var voiceRecordingStack: some View {
        VStack(spacing: 8) {
            if isVoiceHolding {
                HStack {
                    voiceDirectionBadge(
                        icon: "xmark",
                        title: t("toolbar.voice.cancel", "Cancel Recording"),
                        tint: .red,
                        isActive: isDraggingToCancel,
                        alignTrailingIcon: false
                    )

                    Spacer()

                    voiceDirectionBadge(
                        icon: "arrow.up.right",
                        title: t("toolbar.voice.lock", "Keep Recording"),
                        tint: .green,
                        isActive: isDraggingToContinue,
                        alignTrailingIcon: true
                    )
                }
                .padding(.horizontal, cardHPad + 4)
                .offset(x: voiceBadgeOffset.width, y: voiceBadgeOffset.height)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            composerCard {
                voiceRecordingCardContent
            }
            .matchedGeometryEffect(id: "bar", in: morphSpace)
            .padding(.horizontal, cardHPad)
            .offset(x: voiceCardOffset.width, y: voiceCardOffset.height)
        }
        .padding(.bottom, pillH + recordingCardSpacing)
    }

    @ViewBuilder
    private func composerCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26.0, *) {
            content()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        } else {
            content()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .stroke(.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 8)
        }
    }

    private var durationString: String {
        let t = Int(speechRecognizer?.recordingDuration ?? 0)
        return String(format: "%02d:%02d", t / 60, t % 60)
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }

    private var voiceOverlayStrokeColor: Color {
        if isDraggingToCancel { return .red }
        if isDraggingToContinue || isVoiceLocked { return .green }
        return Color.red.opacity(0.32)
    }

    private var voiceTranscriptionPanel: some View {
        Group {
            if hasRecognizedText {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(recognizedText)
                                .font(.system(size: 15))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear.preference(
                                            key: VoiceTranscriptionHeightPreferenceKey.self,
                                            value: geometry.size.height
                                        )
                                    }
                                )

                            Color.clear
                                .frame(height: 1)
                                .id(VoiceTranscriptionBottomAnchor.id)
                        }
                        .frame(maxWidth: .infinity, minHeight: transcriptionPanelHeight, alignment: .topLeading)
                    }
                    .frame(height: transcriptionPanelHeight)
                    .scrollBounceBehavior(.basedOnSize)
                    .defaultScrollAnchor(.bottom)
                    .onAppear {
                        proxy.scrollTo(VoiceTranscriptionBottomAnchor.id, anchor: .bottom)
                    }
                    .onChange(of: recognizedText) { _, _ in
                        proxy.scrollTo(VoiceTranscriptionBottomAnchor.id, anchor: .bottom)
                    }
                    .onPreferenceChange(VoiceTranscriptionHeightPreferenceKey.self) { height in
                        let nextHeight = max(transcriptionMinHeight, height)
                        guard abs(nextHeight - transcriptionContentHeight) > 0.5 else { return }
                        withAnimation(.spring(duration: 0.26, bounce: 0.08)) {
                            transcriptionContentHeight = nextHeight
                        }
                    }
                }
            } else {
                Text(isVoiceLocked ? t("toolbar.voice.locked_hint", "Keep talking, then stop when you're done") : t("toolbar.voice.transcribing", "Transcribing what you're saying…"))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: transcriptionMinHeight, alignment: .bottomLeading)
                    .padding(12)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: hasRecognizedText ? transcriptionPanelHeight : transcriptionMinHeight)
        .animation(.spring(duration: 0.26, bounce: 0.08), value: transcriptionPanelHeight)
        .animation(.easeOut(duration: 0.16), value: hasRecognizedText)
    }

    @ViewBuilder
    private func voiceDirectionBadge(
        icon: String,
        title: String,
        tint: Color,
        isActive: Bool,
        alignTrailingIcon: Bool
    ) -> some View {
        let label = HStack(spacing: 6) {
            if !alignTrailingIcon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
            }

            Text(title)
                .font(.system(size: 13, weight: .semibold))

            if alignTrailingIcon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .foregroundStyle(isActive ? .white : tint)
        .frame(height: 40)
        .padding(.horizontal, 14)

        if #available(iOS 26.0, *) {
            label
                .glassEffect(isActive ? .regular.tint(tint) : .regular, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(isActive ? tint.opacity(0.2) : Color.white.opacity(0.18), lineWidth: 0.8)
                )
                .shadow(color: tint.opacity(isActive ? 0.22 : 0.08), radius: isActive ? 16 : 8, y: 6)
                .scaleEffect(isActive ? 1.03 : 1)
                .animation(.spring(duration: 0.25, bounce: 0.16), value: isActive)
        } else {
            label
                .background(
                    Capsule()
                        .fill(isActive ? tint : Color(uiColor: .systemBackground).opacity(0.88))
                )
                .overlay(
                    Capsule()
                        .stroke(isActive ? tint.opacity(0.22) : tint.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: tint.opacity(isActive ? 0.28 : 0.12), radius: isActive ? 16 : 8, y: 6)
                .scaleEffect(isActive ? 1.03 : 1)
                .animation(.spring(duration: 0.25, bounce: 0.16), value: isActive)
        }
    }

    private func capsuleGestureSurface(containerWidth: CGFloat) -> some View {
        Capsule()
            .fill(Color.black.opacity(0.001))
            .frame(width: max(160, containerWidth - (pillSideInset * 2)), height: pillH)
            .contentShape(Capsule())
        .gesture(voicePressGesture)
    }

    private var voicePressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged(handleVoicePressChanged)
            .onEnded(handleVoicePressEnded)
    }

    // MARK: Voice helpers

    private func startVoiceMode(initialState: VoiceCaptureState = .holding) {
        guard let sr = speechRecognizer else { return }
        guard !isVoiceRecording else { return }
        guard sr.authorizationStatus == .authorized else { return }
        inputFocused = false
        isPillPressed = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
            isOpen = false
            voiceCaptureState = initialState
            activeDragTarget = .none
        }
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
        withAnimation(.spring(duration: 0.3)) {
            voiceCaptureState = .idle
            activeDragTarget = .none
        }
        voiceLevels = Array(repeating: 0.02, count: 24)
        pressStart = nil
        pressToken = UUID()
        longPressTriggered = false
        dragOffset = .zero
        transcriptionContentHeight = transcriptionMinHeight
    }

    private func commitVoice() {
        guard isVoiceRecording, let sr = speechRecognizer else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        sr.stopRecording()
        stopLevelTimer()
        let text  = sr.recognizedText
        let audio = sr.audioData
        if !text.isEmpty { inputText = text }
        onAudioCaptured(audio)
        withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
            isOpen = true
            voiceCaptureState = .idle
            activeDragTarget = .none
        }
        voiceLevels = Array(repeating: 0.02, count: 24)
        pressStart = nil
        pressToken = UUID()
        longPressTriggered = false
        dragOffset = .zero
        transcriptionContentHeight = transcriptionMinHeight
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

    private func handleVoicePressChanged(_ value: DragGesture.Value) {
        if pressStart == nil {
            isPillPressed = true
            beginVoicePress()
        }

        dragOffset = value.translation

        guard isVoiceHolding else { return }
        updateVoiceDragTarget(for: value.translation)
    }

    private func handleVoicePressEnded(_ value: DragGesture.Value) {
        defer {
            pressStart = nil
            longPressTriggered = false
            dragOffset = .zero
            isPillPressed = false
        }

        if isVoiceHolding {
            finishVoiceHold(with: value.translation)
        } else if !longPressTriggered {
            HapticFeedback.light()
            open()
        } else {
            activeDragTarget = .none
        }
    }

    private func beginVoicePress() {
        pressStart = Date()
        pressToken = UUID()
        longPressTriggered = false
        activeDragTarget = .none

        let token = pressToken
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(longPressDuration * 1000)))
            guard pressStart != nil,
                  token == pressToken,
                  !longPressTriggered,
                  !isOpen,
                  voiceCaptureState == .idle
            else { return }
            longPressTriggered = true
            startVoiceMode(initialState: .holding)
        }
    }

    private func updateVoiceDragTarget(for translation: CGSize) {
        let target = voiceDragTarget(for: translation)
        guard target != activeDragTarget else { return }
        if target != .none {
            HapticFeedback.selection()
        }
        withAnimation(.easeOut(duration: 0.16)) {
            activeDragTarget = target
        }
    }

    private func voiceDragTarget(for translation: CGSize) -> VoiceDragTarget {
        let dx = translation.width
        let dy = translation.height
        let distance = hypot(dx, dy)

        guard dy < -26, distance > 30 else { return .none }

        let cancelVector = CGVector(dx: -0.7071, dy: -0.7071)
        let lockVector = CGVector(dx: 0.7071, dy: -0.7071)
        let normalised = CGVector(dx: dx / distance, dy: dy / distance)
        let cancelScore = (normalised.dx * cancelVector.dx) + (normalised.dy * cancelVector.dy)
        let lockScore = (normalised.dx * lockVector.dx) + (normalised.dy * lockVector.dy)

        if cancelScore > 0.80 && dx < -12 { return .cancel }
        if lockScore > 0.80 && dx > 12 { return .lock }
        return .none
    }

    private func finishVoiceHold(with translation: CGSize) {
        switch voiceDragTarget(for: translation) {
        case .cancel:
            cancelVoice()
        case .lock:
            HapticFeedback.medium()
            withAnimation(.spring(duration: 0.35, bounce: 0.14)) {
                voiceCaptureState = .locked
                activeDragTarget = .none
            }
        case .none:
            commitVoice()
        }
    }

    // MARK: Open / Close

    private func open() {
        isPillPressed = false
        isClosingComposer = false
        withAnimation(.spring(duration: 0.45, bounce: 0.2)) { isOpen = true }
    }

    private func close() {
        isPillPressed = false
        isClosingComposer = true
        inputFocused = false
        withAnimation(.spring(duration: 0.4, bounce: 0.1)) { isOpen = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            guard !isOpen else { return }
            inputText = ""
            isClosingComposer = false
        }
    }
}

private enum VoiceTranscriptionBottomAnchor {
    static let id = "voice-transcription-bottom"
}

private struct VoiceTranscriptionHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - AttachmentChip

struct AttachmentChip: View {
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
        BottomCapsuleBar(isOpen: .constant(false), inputText: .constant(""))
    }
}
