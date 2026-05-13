// ContentView.swift — 心泉 Today 主页
// 日期导航 + 每日卡片网格 + 底部工具栏

import SwiftUI
import SwiftData
import PhotosUI

struct ContentView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.modelContext) private var modelContext
    @Environment(SproutMemoryRepository.self) private var memoryRepository
    @Environment(AuthSessionManager.self) private var authSession
    // MARK: UI State
    @State private var isShowingAccountSheet = false
    @State private var isBarOpen             = false
    @State private var composerDraftText     = ""
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

    // MARK: Composer attachments
    @State private var composerAttachments = ComposerAttachments()

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
                    inputText:            $composerDraftText,
                    focusRequestToken:    composerFocusRequestToken,
                    onAction:             handleComposerAction,
                    onRemoveAttachment:   removeAttachment,
                    onSend:               { text in insertRecord(body: text) },
                    onExpandToFullscreen: { showFullscreenEntryComposer = true },
                    attachments:          composerAttachments,
                    speechRecognizer:     speechRecognizer,
                    onAudioCaptured:      { data in composerAttachments.audioData = data }
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
        // MARK: Sheets
        .sheet(isPresented: $isShowingAccountSheet) { AccountManagementSheet() }
        .sheet(isPresented: $showAddCardSheet) {
            AddCardSheet(musicService: musicService, selectedDate: selectedDate)
        }
        .sheet(isPresented: $showFullscreenEntryComposer) {
            FullscreenEntryComposerSheet(
                text: $composerDraftText,
                attachments: $composerAttachments,
                speechRecognizer: speechRecognizer,
                musicService: musicService,
                onAction: handleComposerAction,
                onRemoveAttachment: removeAttachment,
                onSubmit: { text in
                    insertRecord(body: text)
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
                    composerAttachments.photos.append(image)
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
                        composerAttachments.music = pendingMusicData
                        pendingMusicData = MusicCardData()
                    }
                }
        }
        .sheet(isPresented: $showLocationSheet) {
            MapCardSheet(data: $pendingLocationData)
                .onDisappear {
                    if pendingLocationData.coordinate != nil {
                        composerAttachments.locationData = pendingLocationData
                        pendingLocationData = MapCardData()
                    }
                }
        }
        .sheet(isPresented: $showPeopleSheet) {
            PeoplePickerSheet(selectedPeople: $composerAttachments.people)
        }
        // MARK: onChange
        .onChange(of: isBarOpen) { _, newValue in
            // Clear transient attachments when the composer bar closes
            if !newValue { composerAttachments.clear() }
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
                composerAttachments.photos = images
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
        case .rawRecords:
            return "list.bullet.rectangle"
        case .arcs:
            return "timeline.selection"
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
        case .mood:     composerAttachments.mood         = nil
        case .photo:    composerAttachments.photos        = []
        case .location: composerAttachments.locationData = nil
        case .music:    composerAttachments.music         = nil
        case .todo:     composerAttachments.todos         = nil
        case .audio:    composerAttachments.audioData     = nil
        case .people:   composerAttachments.people        = []
        }
    }

    // MARK: Record creation

    /// Creates a photo-only standalone Record (triggered by the quick camera button).
    private func insertStandalonePhotoRecord(image: UIImage) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let createdAt = cal.isDate(selectedDate, inSameDayAs: today)
            ? Date()
            : cal.date(byAdding: .day, value: 1, to: selectedDate)!.addingTimeInterval(-1)

        Task { @MainActor in
            guard let payload = await preparePhotoMediaPayloads(from: [image]).first else { return }

            let record = Record()
            record.cardType = "photo"
            record.createdAt = createdAt
            record.updatedAt = createdAt
            record.dashboardOrder = createdAt.timeIntervalSince1970

            let m = MediaCard()
            m.type = "photo"
            m.imageData = payload.imageData
            m.thumbnailData = payload.thumbnailData
            modelContext.insert(m)
            modelContext.insert(record)
            record.mediaCards = [m]
            let aggregate = memoryAggregateBuilder.build(record: record)
            memoryRepository.upsertAggregate(aggregate)
            await runPostCaptureAnalysisIfPossible(for: aggregate)
        }
    }

    /// Creates a Record from the text body + all pending ComposerAttachments.
    private func insertRecord(body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !composerAttachments.isEmpty else { return }

        Task { @MainActor in
            let attachments = composerAttachments
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let createdAt = cal.isDate(selectedDate, inSameDayAs: today)
                ? Date()
                : cal.date(byAdding: .day, value: 1, to: selectedDate)!.addingTimeInterval(-1)
            let parsed = RecordParser.parseBody(trimmed)
            let photoPayloads = await preparePhotoMediaPayloads(from: attachments.photos)

            let record = Record()
            record.body = trimmed
            record.createdAt = createdAt
            record.updatedAt = createdAt
            record.dashboardOrder = createdAt.timeIntervalSince1970

            if let mood = attachments.mood {
                record.mood = mood.rawValue
                record.intensity = attachments.intensity
            }
            if let loc = attachments.locationData {
                record.latitude = loc.coordinate?.latitude
                record.longitude = loc.coordinate?.longitude
                record.location = loc.locationName.isEmpty ? nil : loc.locationName
            }
            if !attachments.people.isEmpty {
                record.mentionedPeople = attachments.people
                for person in attachments.people {
                    person.lastMentionedAt = record.createdAt
                    person.mentionCount += 1
                }
            }

            var mediaCards: [MediaCard] = []

            for (i, payload) in photoPayloads.enumerated() {
                let m = MediaCard()
                m.type = "photo"
                m.sortIndex = i
                m.imageData = payload.imageData
                m.thumbnailData = payload.thumbnailData
                modelContext.insert(m)
                mediaCards.append(m)
            }

            if let music = attachments.music {
                let m = MediaCard()
                m.type = "music"
                m.url = music.appleMusicURL?.absoluteString
                m.title = music.trackName
                m.caption = music.artistName
                m.albumName = music.albumName.isEmpty ? nil : music.albumName
                m.artworkURLString = music.albumArtworkURL?.absoluteString
                modelContext.insert(m)
                mediaCards.append(m)
            }

            if let todos = attachments.todos, !todos.isEmpty {
                let m = MediaCard()
                m.type = "todo"
                m.title = todos.title
                if let json = try? JSONEncoder().encode(todos.items) {
                    m.caption = String(data: json, encoding: .utf8)
                }
                modelContext.insert(m)
                mediaCards.append(m)
            }

            if let audioData = attachments.audioData {
                let m = MediaCard()
                m.type = "audio"
                m.audioData = audioData
                m.title = localization.string("content.audio.title", default: "Voice %@", arguments: [shortTimeLabel()])
                m.caption = trimmed.isEmpty ? speechRecognizer.recognizedText : trimmed
                m.capturedAt = record.createdAt
                modelContext.insert(m)
                mediaCards.append(m)
            }

            for url in parsed.appleMusicURLs {
                let m = MediaCard()
                m.type = "music"
                m.url = url.absoluteString
                m.title = url.lastPathComponent.replacingOccurrences(of: "-", with: " ")
                m.artworkURLString = nil
                modelContext.insert(m)
                mediaCards.append(m)
            }

            for url in parsed.regularURLs {
                let m = MediaCard()
                m.type = "link"
                m.url = url.absoluteString
                m.title = url.host ?? url.absoluteString
                modelContext.insert(m)
                mediaCards.append(m)
            }

            record.cardType = primaryCardType(parsed: parsed)

            modelContext.insert(record)
            if !mediaCards.isEmpty { record.mediaCards = mediaCards }
            let aggregate = memoryAggregateBuilder.build(record: record)
            memoryRepository.upsertAggregate(aggregate)
            await runPostCaptureAnalysisIfPossible(for: aggregate)

            composerAttachments.clear()
            composerDraftText = ""
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
            memoryRepository.setAnalysis(snapshot, aggregate: aggregate)
        } catch {
            // Keep capture resilient; analysis is best-effort.
        }
    }

    private func primaryCardType(parsed: ParsedContent) -> String {
        if !composerAttachments.photos.isEmpty           { return "photo"   }
        if composerAttachments.music != nil              { return "music"   }
        if composerAttachments.todos != nil              { return "todo"    }
        if composerAttachments.locationData != nil       { return "map"     }
        if composerAttachments.mood != nil               { return "emotion" }
        if composerAttachments.audioData != nil          { return "audio"   }
        if !composerAttachments.people.isEmpty           { return "people"  }
        if !parsed.appleMusicURLs.isEmpty                { return "music"   }
        if !parsed.regularURLs.isEmpty                   { return "link"    }
        return "text"
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
        .modelContainer(
            for: [
                Record.self,
                DayBoard.self,
                BoardComposition.self,
                CompositionItemState.self,
                MediaCard.self,
                Activity.self,
                Person.self,
                DashboardSystemCardConfig.self,
            ],
            inMemory: true
        )
}
