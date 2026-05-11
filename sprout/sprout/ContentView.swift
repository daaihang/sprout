// ContentView.swift — 心泉 Today 主页
// 日期导航 + 每日卡片网格 + 底部工具栏

import SwiftUI
import SwiftData
import PhotosUI

struct ContentView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.modelContext) private var modelContext
    // MARK: UI State
    @State private var isShowingAccountSheet = false
    @State private var isBarOpen             = false
    @State private var selectedDate: Date    = Calendar.current.startOfDay(for: Date())
    @State private var showDatePicker        = false
    @State private var insertionEdge: Edge   = .trailing
    @Environment(\.colorScheme) private var colorScheme

    // MARK: Services
    @State private var musicService     = MusicService()
    @State private var speechRecognizer = SpeechRecognizer()

    // MARK: Composer attachments
    @State private var composerAttachments = ComposerAttachments()

    // Sheet flags
    @State private var showAddCardSheet   = false
    @State private var showCameraSheet    = false
    @State private var showPhotosPicker   = false
    @State private var showMusicSheet     = false
    @State private var showLocationSheet  = false
    @State private var showPeopleSheet    = false
    @State private var showVoiceToast     = false
    @AppStorage("homeDisplayMode") private var homeDisplayModeRawValue = HomeDisplayMode.dashboard.rawValue

    // Pending binding data for attachment sheets
    @State private var pendingMusicData    = MusicCardData()
    @State private var pendingLocationData = MapCardData()
    @State private var pendingPhotoItems: [PhotosPickerItem] = []

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                pageBackground.ignoresSafeArea()

                HomeModeContentView(
                    displayMode: homeDisplayMode,
                    selectedDate: selectedDate,
                    insertionEdge: insertionEdge
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
            .overlay(alignment: .bottom) {
                BottomCapsuleBar(
                    isOpen:               $isBarOpen,
                    onAction:             handleComposerAction,
                    onRemoveAttachment:   removeAttachment,
                    onSend:               { text in insertRecord(body: text) },
                    attachments:          composerAttachments,
                    speechRecognizer:     speechRecognizer,
                    onAudioCaptured:      { data in composerAttachments.audioData = data }
                )
                .ignoresSafeArea(.keyboard)
                .zIndex(10)
            }
            .navigationTitle(" ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                HomeToolbarContent(
                    dateLabel: formattedDateLabel(selectedDate),
                    displayMode: homeDisplayMode,
                    showRecordsLabel: localization.string("content.mode.show_records", default: "Show raw records"),
                    showCardsLabel: localization.string("content.mode.show_cards", default: "Show card grid"),
                    onDateTap: {
                        HapticFeedback.light()
                        showDatePicker.toggle()
                    },
                    onModeToggle: {
                        HapticFeedback.light()
                        toggleHomeDisplayMode()
                    },
                    onProfileTap: {
                        HapticFeedback.light()
                        isShowingAccountSheet = true
                    }
                )
            }
            .modifier(HomeDaySwipeModifier(isEnabled: homeDisplayMode == .dashboard, onNavigateDay: navigateDay))
        }
        .animation(.spring(duration: 0.35, bounce: 0.1), value: selectedDate)
        .animation(.spring(duration: 0.3), value: showVoiceToast)
        // MARK: Sheets
        .sheet(isPresented: $isShowingAccountSheet) { AccountManagementSheet() }
        .sheet(isPresented: $showDatePicker) {
            HomeDatePickerSheet(selectedDate: $selectedDate)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddCardSheet) {
            AddCardSheet(musicService: musicService, selectedDate: selectedDate)
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

    private var homeDisplayMode: HomeDisplayMode {
        HomeDisplayMode(rawValue: homeDisplayModeRawValue) ?? .dashboard
    }

    // MARK: Date navigation

    private func navigateDay(by delta: Int) {
        let cal   = Calendar.current
        let next  = cal.date(byAdding: .day, value: delta, to: selectedDate)!
        let today = cal.startOfDay(for: Date())
        guard next <= today else { return }

        // Both in the same withAnimation for a single render transaction.
        // delta > 0 → going forward (newer) → insertion from trailing (right)
        // delta < 0 → going backward (older) → insertion from leading (left)
        HapticFeedback.selection()
        withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
            insertionEdge = delta > 0 ? .trailing : .leading
            selectedDate  = next
        }
    }

    private func toggleHomeDisplayMode() {
        homeDisplayModeRawValue = homeDisplayMode == .dashboard
            ? HomeDisplayMode.rawRecords.rawValue
            : HomeDisplayMode.dashboard.rawValue
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
        let record = Record()
        record.cardType = "photo"
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        record.createdAt = cal.isDate(selectedDate, inSameDayAs: today)
            ? Date()
            : cal.date(byAdding: .day, value: 1, to: selectedDate)!.addingTimeInterval(-1)
        record.updatedAt = record.createdAt
        record.dashboardOrder = record.createdAt.timeIntervalSince1970

        let m = MediaCard()
        m.type          = "photo"
        m.imageData     = image.jpegData(compressionQuality: 0.85)
        m.thumbnailData = image
            .preparingThumbnail(of: CGSize(width: 300, height: 300))?
            .jpegData(compressionQuality: 0.7)
        modelContext.insert(m)
        modelContext.insert(record)
        record.mediaCards = [m]
    }

    /// Creates a Record from the text body + all pending ComposerAttachments.
    private func insertRecord(body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !composerAttachments.isEmpty else { return }

        let record    = Record()
        record.body   = trimmed

        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        record.createdAt = cal.isDate(selectedDate, inSameDayAs: today)
            ? Date()
            : cal.date(byAdding: .day, value: 1, to: selectedDate)!.addingTimeInterval(-1)
        record.updatedAt = record.createdAt
        record.dashboardOrder = record.createdAt.timeIntervalSince1970

        // Parse body for URLs
        let parsed = RecordParser.parseBody(trimmed)

        // Apply scalar attachments to Record fields
        if let mood = composerAttachments.mood {
            record.mood      = mood.rawValue
            record.intensity = composerAttachments.intensity
        }
        if let loc = composerAttachments.locationData {
            record.latitude  = loc.coordinate?.latitude
            record.longitude = loc.coordinate?.longitude
            record.location  = loc.locationName.isEmpty ? nil : loc.locationName
        }
        if !composerAttachments.people.isEmpty {
            record.mentionedPeople = composerAttachments.people
            for person in composerAttachments.people {
                person.lastMentionedAt = record.createdAt
                person.mentionCount += 1
            }
        }

        // Build media cards
        var mediaCards: [MediaCard] = []

        // Photos
        for (i, img) in composerAttachments.photos.enumerated() {
            let m = MediaCard()
            m.type          = "photo"
            m.sortIndex     = i
            m.imageData     = img.jpegData(compressionQuality: 0.85)
            m.thumbnailData = img
                .preparingThumbnail(of: CGSize(width: 300, height: 300))?
                .jpegData(compressionQuality: 0.7)
            modelContext.insert(m)
            mediaCards.append(m)
        }

        // Music from picker
        if let music = composerAttachments.music {
            let m = MediaCard()
            m.type             = "music"
            m.url              = music.appleMusicURL?.absoluteString
            m.title            = music.trackName
            m.caption          = music.artistName
            m.albumName        = music.albumName.isEmpty ? nil : music.albumName
            m.artworkURLString = music.albumArtworkURL?.absoluteString
            modelContext.insert(m)
            mediaCards.append(m)
        }

        // Todo
        if let todos = composerAttachments.todos, !todos.isEmpty {
            let m = MediaCard()
            m.type  = "todo"
            m.title = todos.title
            if let json = try? JSONEncoder().encode(todos.items) {
                m.caption = String(data: json, encoding: .utf8)
            }
            modelContext.insert(m)
            mediaCards.append(m)
        }

        // Voice recording
        if let audioData = composerAttachments.audioData {
            let m = MediaCard()
            m.type      = "audio"
            m.audioData = audioData
            m.title     = localization.string("content.audio.title", default: "Voice %@", arguments: [shortTimeLabel()])
            m.caption   = trimmed.isEmpty ? speechRecognizer.recognizedText : trimmed
            m.capturedAt = record.createdAt
            modelContext.insert(m)
            mediaCards.append(m)
        }

        // Apple Music URLs parsed from typed text
        for url in parsed.appleMusicURLs {
            let m = MediaCard()
            m.type             = "music"
            m.url              = url.absoluteString
            m.title            = url.lastPathComponent.replacingOccurrences(of: "-", with: " ")
            m.artworkURLString = nil
            modelContext.insert(m)
            mediaCards.append(m)
        }

        // Regular link URLs
        for url in parsed.regularURLs {
            let m = MediaCard()
            m.type  = "link"
            m.url   = url.absoluteString
            m.title = url.host ?? url.absoluteString
            modelContext.insert(m)
            mediaCards.append(m)
        }

        // Determine primary card type by richest attachment
        record.cardType = primaryCardType(parsed: parsed)

        modelContext.insert(record)
        if !mediaCards.isEmpty { record.mediaCards = mediaCards }

        composerAttachments.clear()
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

    // MARK: Background

    private var pageBackground: LinearGradient {
        if colorScheme == .dark {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.08, green: 0.10, blue: 0.16), location: 0.00),
                    .init(color: Color(red: 0.10, green: 0.11, blue: 0.18), location: 0.45),
                    .init(color: Color(red: 0.08, green: 0.12, blue: 0.10), location: 1.00),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.78, green: 0.91, blue: 0.97), location: 0.00),
                    .init(color: Color(red: 0.88, green: 0.93, blue: 0.99), location: 0.45),
                    .init(color: Color(red: 0.92, green: 0.96, blue: 0.92), location: 1.00),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(
            for: [
                Record.self,
                MediaCard.self,
                Activity.self,
                Person.self,
                DashboardSystemCardConfig.self,
            ],
            inMemory: true
        )
}
