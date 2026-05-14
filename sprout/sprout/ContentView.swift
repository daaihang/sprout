// ContentView.swift — 心泉 Today 主页
// 日期导航 + 每日卡片网格 + 底部工具栏

import SwiftUI
import SwiftData
import PhotosUI

struct ContentView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(SproutMemoryRepository.self) private var memoryRepository
    @Environment(AuthSessionManager.self) private var authSession
    // MARK: UI State
    @State private var isShowingAccountSheet = false
    @State private var isBarOpen             = false
    @State private var captureDraftStore     = CaptureDraftStore()
    @State private var composerFocusRequestToken = 0
    @State private var selectedDate: Date    = Calendar.current.startOfDay(for: Date())
    @State private var isTopDrawerPresented  = false
    @State private var topSafeAreaInset: CGFloat = 0
    @State private var navigationBarMaxY: CGFloat = 0
    @AppStorage("homeTopDrawerTag") private var selectedTopDrawerTagRawValue = HomeTopDrawerTag.cards.rawValue

    // MARK: Services
    @State private var musicService     = MusicService()
    @State private var speechRecognizer = SpeechRecognizer()
    private let memoryAggregateBuilder = SproutMemoryAggregateBuilder()
    private let analyzeService = SproutAnalyzeService()

    // Sheet flags
    @State private var showAddCardSheet   = false
    @State private var showCameraSheet    = false
    @State private var showPhotosPicker   = false
    @State private var showMusicSheet     = false
    @State private var showLocationSheet  = false
    @State private var showPeopleSheet    = false
    @State private var showFullscreenEntryComposer = false
    @State private var showVoiceToast     = false

    // Pending binding data for attachment sheets
    @State private var pendingMusicData    = MusicCardData()
    @State private var pendingLocationData = MapCardData()
    @State private var pendingPhotoItems: [PhotosPickerItem] = []

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                HomeBackgroundView().ignoresSafeArea()

                HomeModeContentView(
                    selectedTag: selectedTopDrawerTagBinding,
                    selectedDate: $selectedDate,
                    cardsTopInset: drawerTopInset,
                    onPrimaryContentInteraction: closeTopDrawerIfNeeded
                )

                if shouldShowDraftResumeBanner {
                    VStack {
                        Spacer()
                        draftResumeBanner
                            .padding(.horizontal, 18)
                            .padding(.bottom, 94)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .zIndex(6)
                }

                // Voice toast overlay
                if showVoiceToast {
                    Text(localization.string("content.voice_coming_soon", default: "Voice input coming soon", table: "Content"))
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 8)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            topSafeAreaInset = geometry.safeAreaInsets.top
                        }
                        .onChange(of: geometry.safeAreaInsets.top) { _, newValue in
                            topSafeAreaInset = newValue
                        }
                }
            )
            .background(
                NavigationBarFrameReader { maxY in
                    navigationBarMaxY = maxY
                }
            )
            .overlay(alignment: .bottom) {
                BottomCapsuleBar(
                    isOpen:               $isBarOpen,
                    inputText:            captureTextArtifactBinding,
                    focusRequestToken:    composerFocusRequestToken,
                    onAction:             handleComposerAction,
                    onRemoveAttachment:   removeAttachment,
                    onSend:               { _ in submitCaptureDraft() },
                    onExpandToFullscreen: { showFullscreenEntryComposer = true },
                    attachments:          captureDraftStore.draft.attachments,
                    speechRecognizer:     speechRecognizer,
                    onAudioCaptured:      { data in captureDraftStore.draft.attachments.audioData = data }
                )
                .zIndex(10)
            }
            .overlay(alignment: .top) {
                if isTopDrawerPresented {
                    HomeTopTabsBar(
                        selectedTag: selectedTopDrawerTagBinding,
                        isPresented: isTopDrawerPresented
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(true)
                }
            }
            .navigationTitle(" ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .tabBar)
            .toolbar {
                HomeToolbarContent(
                    dateLabel: navigationTitleText,
                    leadingSymbolName: navigationLeadingSymbolName,
                    onMenuTap: {
                        HapticFeedback.light()
                        toggleTopDrawer()
                    },
                    onProfileTap: {
                        HapticFeedback.light()
                        isShowingAccountSheet = true
                    }
                )
            }
        }
        .animation(.spring(duration: 0.3), value: showVoiceToast)
        .animation(.smooth(duration: 0.32), value: isTopDrawerPresented)
        .animation(.smooth(duration: 0.28), value: shouldShowDraftResumeBanner)
        // MARK: Sheets
        .sheet(isPresented: $isShowingAccountSheet) { AccountManagementSheet() }
        .sheet(isPresented: $showAddCardSheet) {
            AddCardSheet(musicService: musicService, selectedDate: selectedDate)
        }
        .sheet(isPresented: $showFullscreenEntryComposer) {
            FullscreenEntryComposerSheet(
                text: captureTextArtifactBinding,
                attachments: captureAttachmentsBinding,
                speechRecognizer: speechRecognizer,
                musicService: musicService,
                onAction: handleComposerAction,
                onRemoveAttachment: removeAttachment,
                onSubmit: { _ in
                    submitCaptureDraft()
                    showFullscreenEntryComposer = false
                    isBarOpen = false
                },
                onClose: {
                    showFullscreenEntryComposer = false
                    isBarOpen = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(220))
                        composerFocusRequestToken += 1
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showCameraSheet) {
            CameraView { image in
                if isBarOpen {
                    captureDraftStore.draft.attachments.photos.append(image)
                } else {
                    insertStandalonePhotoRecord(image: image)
                }
            }
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection:   $pendingPhotoItems,
            maxSelectionCount: 9,
            matching:    .images
        )
        .sheet(isPresented: $showMusicSheet) {
            MusicCardSheet(data: $pendingMusicData, musicService: musicService)
                .onDisappear {
                    if !pendingMusicData.trackName.isEmpty {
                        captureDraftStore.draft.attachments.music = pendingMusicData
                        pendingMusicData = MusicCardData()
                    }
                }
        }
        .sheet(isPresented: $showLocationSheet) {
            MapCardSheet(data: $pendingLocationData)
                .onDisappear {
                    if pendingLocationData.coordinate != nil {
                        captureDraftStore.draft.attachments.locationData = pendingLocationData
                        pendingLocationData = MapCardData()
                    }
                }
        }
        .sheet(isPresented: $showPeopleSheet) {
            PeoplePickerSheet(selectedPeople: capturePeopleBinding)
        }
        // MARK: onChange
        .onChange(of: isBarOpen) { _, newValue in
            captureDraftStore.handleComposerPresentationChange(isPresented: newValue)
        }
        .onChange(of: pendingPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img  = UIImage(data: data) {
                        images.append(img)
                    }
                }
                captureDraftStore.draft.attachments.photos = images
                pendingPhotoItems = []
            }
        }
        .onAppear {
            Task { await speechRecognizer.requestAuthorization() }
        }
    }

    private var selectedTopDrawerTag: HomeTopDrawerTag {
        HomeTopDrawerTag(persistedValue: selectedTopDrawerTagRawValue)
    }

    private var selectedTopDrawerTagBinding: Binding<HomeTopDrawerTag> {
        Binding(
            get: { selectedTopDrawerTag },
            set: { selectedTopDrawerTagRawValue = $0.rawValue }
        )
    }

    private var drawerTopInset: CGFloat {
        max(navigationBarMaxY, topSafeAreaInset)
    }

    private var shouldShowDraftResumeBanner: Bool {
        !isBarOpen && !showFullscreenEntryComposer && captureDraftStore.hasRestorableDraft
    }

    private var captureTextArtifactBinding: Binding<String> {
        Binding(
            get: { captureDraftStore.draft.textArtifactText },
            set: { captureDraftStore.draft.textArtifactText = $0 }
        )
    }

    private var draftResumeBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Draft Saved")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(draftResumeSubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button {
                HapticFeedback.light()
                captureDraftStore.discardDraft()
            } label: {
                Text("Discard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
            }

            Button {
                HapticFeedback.selection()
                captureDraftStore.restoreIfNeeded()
                isBarOpen = true
                composerFocusRequestToken += 1
            } label: {
                Text("Resume")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentColor, in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 6)
    }

    private var draftResumeSubtitle: String {
        let draft = captureDraftStore.draft
        var parts: [String] = []
        if draft.hasTextArtifact {
            parts.append("Text artifact")
        }
        if draft.attachments.hasArtifacts {
            parts.append(draft.attachments.artifactCountLabel)
        }
        if parts.isEmpty {
            return "You have an unfinished capture ready to continue."
        }
        return parts.joined(separator: " + ")
    }

    private var captureAttachmentsBinding: Binding<ComposerAttachments> {
        Binding(
            get: { captureDraftStore.draft.attachments },
            set: { captureDraftStore.draft.attachments = $0 }
        )
    }

    private var capturePeopleBinding: Binding<[PersonCardItem]> {
        Binding(
            get: { captureDraftStore.draft.attachments.people },
            set: { captureDraftStore.draft.attachments.people = $0 }
        )
    }

    private var navigationTitleText: String {
        if selectedTopDrawerTag == .cards {
            return formattedDateLabel(selectedDate)
        }
        return localization.string(selectedTopDrawerTag.localizationKey, default: selectedTopDrawerTag.defaultTitle)
    }

    private var navigationLeadingSymbolName: String {
        switch selectedTopDrawerTag {
        case .cards:
            return "square.grid.2x2"
        case .people:
            return "person.2"
        case .memories:
            return "list.bullet.rectangle"
        case .arcs:
            return "timeline.selection"
        case .reflections:
            return "sparkles"
        case .search:
            return "magnifyingglass"
        case .decisions, .map, .photos:
            return "ellipsis.circle"
        }
    }

    private func toggleTopDrawer() {
        if isTopDrawerPresented {
            closeTopDrawer()
        } else {
            withAnimation(.smooth(duration: 0.42)) {
                isTopDrawerPresented = true
            }
        }
    }

    private func closeTopDrawer() {
        withAnimation(.smooth(duration: 0.42)) {
            isTopDrawerPresented = false
        }
    }

    private func closeTopDrawerIfNeeded() {
        guard isTopDrawerPresented else { return }
        closeTopDrawer()
    }

    private func formattedDateLabel(_ date: Date) -> String {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        if cal.isDate(date, inSameDayAs: today) {
            return localization.string("content.date.today", default: "Today", table: "Content")
        }
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        if cal.isDate(date, inSameDayAs: yesterday) {
            return localization.string("content.date.yesterday", default: "Yesterday", table: "Content")
        }
        return localization.templateDateString(from: date, template: "MMM d EEE")
    }

    // MARK: Composer action handler

    private func handleComposerAction(_ action: ComposerActionType) {
        switch action {
        case .addCard:
            showAddCardSheet = true
        case .camera:
            showCameraSheet = true
        case .photo:
            showPhotosPicker = true
        case .location:
            showLocationSheet = true
        case .people:
            openPeoplePicker()
        case .music:
            showMusicSheet = true
        case .link:
            break   // RecordParser handles URLs typed in the text field
        case .voice:
            // Handled internally by BottomCapsuleBar long-press gesture.
            // This case is reached only if something calls onAction(.voice) externally.
            showVoiceToast = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                showVoiceToast = false
            }
        }
    }

    private func removeAttachment(_ key: ComposerAttachmentKey) {
        switch key {
        case .mood:     captureDraftStore.draft.attachments.mood         = nil
        case .photo:    captureDraftStore.draft.attachments.photos        = []
        case .location: captureDraftStore.draft.attachments.locationData = nil
        case .music:    captureDraftStore.draft.attachments.music         = nil
        case .todo:     captureDraftStore.draft.attachments.todos         = nil
        case .audio:    captureDraftStore.draft.attachments.audioData     = nil
        case .people:   captureDraftStore.draft.attachments.people        = []
        }
    }

    private func submitCaptureDraft() {
        guard let draft = captureDraftStore.currentSubmissionDraft() else { return }
        insertRecord(from: draft)
    }

    // MARK: Record creation

    /// Creates a photo-only standalone Record (triggered by the quick camera button).
    private func insertStandalonePhotoRecord(image: UIImage) {
        let createdAt = Date()

        Task { @MainActor in
            let payloads = await preparePhotoMediaPayloads(from: [image])
            guard !payloads.isEmpty else { return }

            let draft = CaptureDraft(
                textArtifactText: "",
                attachments: ComposerAttachments(photos: [image])
            )
            let aggregate = memoryAggregateBuilder.build(
                draft: draft,
                createdAt: createdAt,
                captureSource: .photo,
                photoPayloads: payloads
            )
            do {
                try memoryRepository.upsertAggregate(aggregate)
                await runPostCaptureAnalysisIfPossible(for: aggregate)
            } catch {
                return
            }
        }
    }

    /// Creates a Record from one capture draft: text artifact + bundled artifacts.
    private func insertRecord(from draft: CaptureDraft) {
        guard draft.hasContent else { return }

        Task { @MainActor in
            let trimmed = draft.trimmedTextArtifactText
            let attachments = draft.attachments
            let createdAt = Date()
            let parsed = RecordParser.parseBody(trimmed)
            let photoPayloads = await preparePhotoMediaPayloads(from: attachments.photos)
            let aggregate = memoryAggregateBuilder.build(
                draft: draft,
                createdAt: createdAt,
                captureSource: draft.attachments.audioData == nil ? .composer : .voice,
                parsed: parsed,
                photoPayloads: photoPayloads
            )
            do {
                try memoryRepository.upsertAggregate(aggregate)
                await runPostCaptureAnalysisIfPossible(for: aggregate)
                captureDraftStore.reset()
            } catch {
                return
            }
        }
    }

    @MainActor
    private func runPostCaptureAnalysisIfPossible(for aggregate: SproutMemoryAggregate) async {
        guard let session = authSession.currentSession else { return }
        guard session.mode != "development_stub" || !session.accessToken.isEmpty else { return }

        do {
            let response = try await analyzeService.analyzeRecord(aggregate: aggregate, session: session)
            let snapshot = analyzeService.mapToAnalysisSnapshot(
                response: response,
                recordID: aggregate.recordShell.id
            )
            try memoryRepository.setAnalysis(snapshot, aggregate: aggregate)
        } catch {
            // Keep capture resilient; analysis is best-effort.
        }
    }

    private func shortTimeLabel() -> String {
        let f = DateFormatter()
        f.locale = localization.locale
        f.setLocalizedDateFormatFromTemplate("HH:mm")
        return f.string(from: Date())
    }

    private func openPeoplePicker() {
        showPeopleSheet = true
    }
}

private struct NavigationBarFrameReader: UIViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> NavigationBarProbeView {
        let view = NavigationBarProbeView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: NavigationBarProbeView, context: Context) {
        uiView.onChange = onChange
        uiView.report()
    }
}

private final class NavigationBarProbeView: UIView {
    var onChange: ((CGFloat) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        report()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        report()
    }

    func report() {
        guard let navigationController = sequence(first: next, next: { $0?.next })
            .compactMap({ $0 as? UINavigationController })
            .first
        else { return }

        let frame = navigationController.navigationBar.convert(
            navigationController.navigationBar.bounds,
            to: nil
        )
        onChange?(frame.maxY)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(try! ModelContainer(for: MemoryModelSchema.makeSchema(), configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}
