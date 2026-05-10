// ContentView.swift — 心泉 Today 主页
// 日期导航 + 每日卡片网格 + 底部工具栏

import SwiftUI
import SwiftData
import PhotosUI

struct ContentView: View {
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
    @State private var showVoiceToast     = false

    // Pending binding data for attachment sheets
    @State private var pendingMusicData    = MusicCardData()
    @State private var pendingLocationData = MapCardData()
    @State private var pendingPhotoItems: [PhotosPickerItem] = []

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                pageBackground.ignoresSafeArea()

                // Daily card grid — re-created when selectedDate changes
                DailyView(date: selectedDate)
                    .id(selectedDate)
                    .transition(.asymmetric(
                        insertion: .move(edge: insertionEdge),
                        removal:   .move(edge: insertionEdge == .leading ? .trailing : .leading)
                    ))

                BottomCapsuleBar(
                    isOpen:               $isBarOpen,
                    onAction:             handleComposerAction,
                    onRemoveAttachment:   removeAttachment,
                    onSend:               { text in insertRecord(body: text) },
                    attachments:          composerAttachments,
                    speechRecognizer:     speechRecognizer,
                    onAudioCaptured:      { data in composerAttachments.audioData = data }
                )

                // Voice toast overlay
                if showVoiceToast {
                    Text("🎙 即将推出")
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showDatePicker.toggle() } label: {
                        HStack(spacing: 4) {
                            Text(formattedDateLabel(selectedDate))
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                                .contentTransition(.numericText())
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isShowingAccountSheet = true } label: {
                        Image(systemName: "person")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            // Swipe left/right to change date
            // Left = forward (newer), right = backward (older) — matches iOS Calendar convention
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        if value.translation.width < -40 {
                            navigateDay(by: +1)   // swipe left → next day (forward)
                        } else if value.translation.width > 40 {
                            navigateDay(by: -1)   // swipe right → previous day (backward)
                        }
                    }
            )
        }
        .animation(.spring(duration: 0.35, bounce: 0.1), value: selectedDate)
        .animation(.spring(duration: 0.3), value: showVoiceToast)
        // MARK: Sheets
        .sheet(isPresented: $isShowingAccountSheet) { AccountManagementSheet() }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
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

    // MARK: Date navigation

    private func navigateDay(by delta: Int) {
        let cal   = Calendar.current
        let next  = cal.date(byAdding: .day, value: delta, to: selectedDate)!
        let today = cal.startOfDay(for: Date())
        guard next <= today else { return }

        // Both in the same withAnimation for a single render transaction.
        // delta > 0 → going forward (newer) → insertion from trailing (right)
        // delta < 0 → going backward (older) → insertion from leading (left)
        withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
            insertionEdge = delta > 0 ? .trailing : .leading
            selectedDate  = next
        }
    }

    private func formattedDateLabel(_ date: Date) -> String {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        if cal.isDate(date, inSameDayAs: today) { return "今日" }
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        if cal.isDate(date, inSameDayAs: yesterday) { return "昨天" }
        let f = DateFormatter()
        f.locale     = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 · EEE"
        return f.string(from: date)
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
        case .music:
            showMusicSheet = true
        case .voice:
            // Handled internally by BottomCapsuleBar long-press gesture.
            // This case is reached only if something calls onAction(.voice) externally.
            showVoiceToast = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                showVoiceToast = false
            }
        case .link:
            break   // RecordParser handles URLs typed in the text field
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
            m.type    = "music"
            m.url     = music.appleMusicURL?.absoluteString
            m.title   = music.trackName
            m.caption = music.artistName
            if let img = music.albumArtwork {
                m.thumbnailData = img.jpegData(compressionQuality: 0.8)
            }
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
            m.title     = "语音 \(shortTimeLabel())"
            modelContext.insert(m)
            mediaCards.append(m)
        }

        // Apple Music URLs parsed from typed text
        for url in parsed.appleMusicURLs {
            let m = MediaCard()
            m.type  = "music"
            m.url   = url.absoluteString
            m.title = url.lastPathComponent.replacingOccurrences(of: "-", with: " ")
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
        if composerAttachments.audioData != nil          { return "text"    }
        if !parsed.appleMusicURLs.isEmpty                { return "music"   }
        if !parsed.regularURLs.isEmpty                   { return "link"    }
        return "text"
    }

    private func shortTimeLabel() -> String {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
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

// MARK: - DatePickerSheet

private struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "选择日期",
                    selection: $selectedDate,
                    in: ...Calendar.current.startOfDay(for: Date()),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .onChange(of: selectedDate) { _, new in
                    let norm = Calendar.current.startOfDay(for: new)
                    if norm != selectedDate { selectedDate = norm }
                }
            }
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [Record.self, MediaCard.self, Activity.self], inMemory: true)
}
