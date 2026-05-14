import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation

// MARK: - AddCardSheet

/// Sheet presented by the "+" button.
/// Creates standalone Records (independent of the text composer).
struct AddCardSheet: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @Environment(SproutMemoryRepository.self) private var memoryRepository
    @Environment(AuthSessionManager.self) private var authSession
    @Environment(CapturePipelineStore.self) private var capturePipeline

    var musicService: MusicService
    var selectedDate: Date

    // MARK: Internal navigation step

    private enum Step { case grid, emotion, weather, todo }
    @State private var step: Step = .grid

    // MARK: Sub-editor state

    @State private var emotionData  = EmotionCardData()
    @State private var weatherData  = WeatherCardData()
    @State private var todoData     = TodoCardData(title: "")
    @StateObject private var weatherService = WeatherDataService()
    @State private var isFetchingWeatherSnapshot = false
    @State private var weatherFetchError: String?

    // Sheets for types that re-use existing pickers
    @State private var musicData        = MusicCardData()
    @State private var locationData     = MapCardData()
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var capturedImages: [UIImage] = []

    @State private var showMusicSheet    = false
    @State private var showLocationSheet = false
    @State private var showPhotosPicker  = false
    @State private var captureErrorMessage: String? = nil
    private let memoryAggregateBuilder = SproutMemoryAggregateBuilder()
    private let analyzeService = SproutAnalyzeService()

    // MARK: Body

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .grid:    gridView
                case .emotion: emotionEditorView
                case .weather: weatherEditorView
                case .todo:    todoEditorView
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .grid ? t("common.cancel", "Cancel") : t("common.back", "Back")) {
                        if step == .grid { dismiss() } else { step = .grid }
                    }
                }
                if step != .grid {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(t("common.save", "Save")) { confirmCurrentStep() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        // Music
        .sheet(isPresented: $showMusicSheet) {
            MusicCardSheet(data: $musicData, musicService: musicService)
                .onDisappear {
                    if !musicData.trackName.isEmpty { confirmStandalone(type: "music") }
                }
        }
        // Location
        .sheet(isPresented: $showLocationSheet) {
            MapCardSheet(data: $locationData)
                .onDisappear {
                    if locationData.coordinate != nil { confirmStandalone(type: "map") }
                }
        }
        // Photos
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $photoItems,
            maxSelectionCount: 9,
            matching: .images
        )
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img  = UIImage(data: data) {
                        images.append(img)
                    }
                }
                capturedImages = images
                if !images.isEmpty { confirmStandalone(type: "photo") }
            }
        }
        .alert(
            localization.string("capture.error.alert_title", default: "Capture failed"),
            isPresented: Binding(
                get: { captureErrorMessage != nil },
                set: { if !$0 { captureErrorMessage = nil } }
            ),
            actions: {
                Button(t("common.ok", "OK")) {
                    captureErrorMessage = nil
                }
            },
            message: {
                Text(captureErrorMessage ?? "")
            }
        )
    }

    // MARK: Grid

    private var gridView: some View {
        let types: [(label: String, icon: String, color: Color, action: () -> Void)] = [
            (t("add_card.type.photo", "Photo"),  "photo.on.rectangle.angled", .blue,   { showPhotosPicker   = true }),
            (t("add_card.type.emotion", "Emotion"),  "face.smiling",              .orange, { step = .emotion }),
            (t("add_card.type.weather", "Weather"),  "cloud.sun.fill",             .yellow, { step = .weather }),
            (t("add_card.type.location", "Location"),  "location.fill",              .red,    { showLocationSheet  = true }),
            (t("add_card.type.todo", "To-Do"),  "checklist",                  .green,  { step = .todo }),
            (t("add_card.type.music", "Music"),  "music.note",                 .purple, { showMusicSheet     = true }),
        ]
        return ScrollView {
            LazyVGrid(
                columns: [SwiftUI.GridItem(.flexible()), SwiftUI.GridItem(.flexible()), SwiftUI.GridItem(.flexible())],
                spacing: 20
            ) {
                ForEach(types, id: \.label) { item in
                    Button(action: item.action) {
                        VStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(item.color.opacity(0.12))
                                    .frame(width: 64, height: 64)
                                Image(systemName: item.icon)
                                    .font(.system(size: 26))
                                    .foregroundStyle(item.color)
                                    .symbolRenderingMode(.multicolor)
                            }
                            Text(item.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28)
        }
    }

    // MARK: Emotion editor

    private var emotionEditorView: some View {
        List {
            Section {
                LazyVGrid(
                    columns: Array(repeating: SwiftUI.GridItem(.flexible()), count: 3),
                    spacing: 12
                ) {
                    ForEach(MoodType.allCases, id: \.self) { mood in
                        Button { emotionData.mood = mood } label: {
                            VStack(spacing: 4) {
                                Text(mood.emoji).font(.system(size: 36))
                                Text(mood.label).font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                emotionData.mood == mood
                                    ? mood.color.opacity(0.18)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text(t("add_card.emotion.section", "Emotion"))
            }

            Section {
                HStack(spacing: 16) {
                    Text(t("add_card.emotion.intensity", "Intensity"))
                        .font(.subheadline)
                    Spacer()
                    HStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { i in
                            Button { emotionData.intensity = i } label: {
                                Circle()
                                    .fill(i <= emotionData.intensity
                                          ? emotionData.mood.color
                                          : emotionData.mood.color.opacity(0.2))
                                    .frame(width: 26, height: 26)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                TextField(t("add_card.emotion.note_placeholder", "Notes (optional)"), text: $emotionData.note, axis: .vertical)
                    .lineLimit(2...5)
            } header: {
                Text(t("add_card.emotion.note", "Notes"))
            }
        }
    }

    // MARK: Weather editor

    private var weatherEditorView: some View {
        List {
            Section {
                Button {
                    Task { await loadCurrentWeatherSnapshot(force: true) }
                } label: {
                    HStack(spacing: 12) {
                        if isFetchingWeatherSnapshot {
                            ProgressView()
                        } else {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isFetchingWeatherSnapshot ? t("add_card.weather.loading", "Fetching weather for your current location") : t("add_card.weather.use_current", "Use current location weather"))
                            Text(t("add_card.weather.snapshot_hint", "Save it as a weather snapshot for this entry"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(isFetchingWeatherSnapshot)

                if let weatherFetchError, !weatherFetchError.isEmpty {
                    Text(weatherFetchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text(t("add_card.weather.footer", "Weather cards can only be filled from your current location automatically."))
            }

            if weatherData.observedAt != nil {
                Section(t("add_card.weather.snapshot", "Weather Snapshot")) {
                    HStack {
                        Label(weatherData.condition.label, systemImage: weatherData.condition.sfSymbol)
                            .foregroundStyle(weatherData.condition.color)
                        Spacer()
                        Text("\(Int(weatherData.temperature))°C")
                            .fontWeight(.semibold)
                    }

                    LabeledContent(t("add_card.weather.location", "Location"), value: weatherData.location.isEmpty ? t("weather.current_location", "Current Location") : weatherData.location)
                    LabeledContent(t("add_card.weather.feels_like", "Feels Like"), value: "\(Int(weatherData.feelsLike))°C")
                    LabeledContent(t("add_card.weather.humidity", "Humidity"), value: "\(weatherData.humidity)%")
                    LabeledContent(t("add_card.weather.high_low", "High / Low"), value: "\(Int(weatherData.high))° / \(Int(weatherData.low))°")

                    if let observedAt = weatherData.observedAt {
                        LabeledContent(t("add_card.weather.observed_at", "Fetched At"), value: observedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
        }
        .task {
            await loadCurrentWeatherSnapshot(force: false)
        }
        .onChange(of: weatherService.authorizationStatus) { _, _ in
            Task { await loadCurrentWeatherSnapshot(force: false) }
        }
    }

    // MARK: Todo editor

    private var todoEditorView: some View {
        List {
            Section {
                TextField(t("add_card.todo.title_placeholder", "List title (optional)"), text: $todoData.title)
            }

            Section {
                ForEach($todoData.items) { $item in
                    HStack(spacing: 12) {
                        Button { item.isDone.toggle() } label: {
                            Image(systemName: item.isDone
                                  ? "checkmark.square.fill" : "square")
                                .foregroundStyle(item.isDone ? .green : .secondary)
                                .font(.title3)
                        }
                        TextField(t("add_card.todo.item_placeholder", "To-do item"), text: $item.text)
                    }
                }
                .onDelete { todoData.items.remove(atOffsets: $0) }

                Button {
                    todoData.items.append(TodoItem(text: ""))
                } label: {
                    Label(t("add_card.todo.add_item", "Add Item"), systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            } header: {
                Text(t("add_card.todo.section", "To-Do Items"))
            }
        }
    }

    // MARK: Confirm helpers

    private var navTitle: String {
        switch step {
        case .grid:    return t("add_card.nav.grid", "New Card")
        case .emotion: return t("add_card.nav.emotion", "Log Emotion")
        case .weather: return t("add_card.nav.weather", "Log Weather")
        case .todo:    return t("add_card.nav.todo", "Create To-Do")
        }
    }

    private func confirmCurrentStep() {
        switch step {
        case .emotion: confirmStandalone(type: "emotion")
        case .weather: confirmStandalone(type: "weather")
        case .todo:    confirmStandalone(type: "todo")
        case .grid:    break
        }
    }

    /// Creates a standalone Record of the given type and inserts it into SwiftData.
    private func confirmStandalone(type selectedCardType: String) {
        capturePipeline.beginSaving()
        let createdAt = Date()
        let recordID = UUID()
        let presentationKind = MemoryPresentationKind(rawValue: selectedCardType) ?? .text

        switch selectedCardType {

        case "emotion":
            let aggregate = memoryAggregateBuilder.buildStandaloneAggregate(
                presentationKind: presentationKind,
                recordID: recordID,
                createdAt: createdAt,
                textArtifactText: emotionData.note,
                emotion: emotionData
            )
            persistStandaloneRecord(for: aggregate)
            guard persistLocalChanges(recordID: aggregate.recordShell.id) else { return }
            memoryRepository.upsertAggregate(aggregate)
            Task { await runPostCaptureAnalysisIfPossible(for: aggregate) }
            dismiss()

        case "weather":
            let aggregate = memoryAggregateBuilder.buildStandaloneAggregate(
                presentationKind: presentationKind,
                recordID: recordID,
                createdAt: createdAt,
                weather: weatherData
            )
            persistStandaloneRecord(for: aggregate)
            guard persistLocalChanges(recordID: aggregate.recordShell.id) else { return }
            memoryRepository.upsertAggregate(aggregate)
            Task { await runPostCaptureAnalysisIfPossible(for: aggregate) }
            dismiss()

        case "map":
            let aggregate = memoryAggregateBuilder.buildStandaloneAggregate(
                presentationKind: presentationKind,
                recordID: recordID,
                createdAt: createdAt,
                textArtifactText: locationData.descriptionText,
                location: locationData
            )
            persistStandaloneRecord(for: aggregate)
            guard persistLocalChanges(recordID: aggregate.recordShell.id) else { return }
            memoryRepository.upsertAggregate(aggregate)
            Task { await runPostCaptureAnalysisIfPossible(for: aggregate) }
            dismiss()

        case "music":
            let aggregate = memoryAggregateBuilder.buildStandaloneAggregate(
                presentationKind: presentationKind,
                recordID: recordID,
                createdAt: createdAt,
                music: musicData
            )
            persistStandaloneRecord(for: aggregate)
            guard persistLocalChanges(recordID: aggregate.recordShell.id) else { return }
            memoryRepository.upsertAggregate(aggregate)
            Task { await runPostCaptureAnalysisIfPossible(for: aggregate) }
            dismiss()

        case "photo":
            Task { @MainActor in
                let payloads = await preparePhotoMediaPayloads(from: capturedImages)
                let aggregate = memoryAggregateBuilder.buildStandaloneAggregate(
                    presentationKind: presentationKind,
                    recordID: recordID,
                    createdAt: createdAt,
                    photoPayloads: payloads
                )
                persistStandaloneRecord(for: aggregate)
                guard persistLocalChanges(recordID: aggregate.recordShell.id) else { return }
                memoryRepository.upsertAggregate(aggregate)
                Task { await runPostCaptureAnalysisIfPossible(for: aggregate) }
                dismiss()
            }

        case "todo":
            guard !todoData.isEmpty else { return }
            let aggregate = memoryAggregateBuilder.buildStandaloneAggregate(
                presentationKind: presentationKind,
                recordID: recordID,
                createdAt: createdAt,
                todo: todoData
            )
            persistStandaloneRecord(for: aggregate)
            guard persistLocalChanges(recordID: aggregate.recordShell.id) else { return }
            memoryRepository.upsertAggregate(aggregate)
            Task { await runPostCaptureAnalysisIfPossible(for: aggregate) }
            dismiss()

        default:
            let aggregate = memoryAggregateBuilder.buildStandaloneAggregate(
                presentationKind: presentationKind,
                recordID: recordID,
                createdAt: createdAt,
                textArtifactText: ""
            )
            persistStandaloneRecord(for: aggregate)
            guard persistLocalChanges(recordID: aggregate.recordShell.id) else { return }
            memoryRepository.upsertAggregate(aggregate)
            Task { await runPostCaptureAnalysisIfPossible(for: aggregate) }
            dismiss()
        }
    }

    @MainActor
    private func persistStandaloneRecord(for aggregate: SproutMemoryAggregate) {
        let record = Record()
        record.id = aggregate.recordShell.id
        record.createdAt = aggregate.recordShell.createdAt
        record.updatedAt = aggregate.recordShell.updatedAt
        record.dashboardOrder = aggregate.recordShell.createdAt.timeIntervalSince1970
        record.mood = aggregate.recordShell.userMood
        record.intensity = aggregate.recordShell.userIntensity
        modelContext.insert(record)
    }

    @MainActor
    private func runPostCaptureAnalysisIfPossible(for aggregate: SproutMemoryAggregate) async {
        guard let session = authSession.currentSession else { return }
        guard session.mode != "development_stub" else {
            capturePipeline.markAnalysisUnavailable(
                recordID: aggregate.recordShell.id,
                detail: t("capture.analysis.dev_stub_unavailable", "Development bypass mode skips authenticated AI analysis.")
            )
            return
        }
        guard !session.accessToken.isEmpty else {
            capturePipeline.markAnalysisUnavailable(
                recordID: aggregate.recordShell.id,
                detail: t("capture.analysis.missing_token", "The session is missing an access token, so AI analysis was skipped.")
            )
            return
        }

        capturePipeline.markAnalyzing(
            recordID: aggregate.recordShell.id,
            detail: t("capture.analysis.running", "Sending record aggregate to the analysis service.")
        )

        do {
            let response = try await analyzeService.analyzeRecord(aggregate: aggregate, session: session)
            let snapshot = analyzeService.mapToAnalysisSnapshot(
                response: response,
                recordID: aggregate.recordShell.id
            )
            memoryRepository.setAnalysis(snapshot, aggregate: aggregate)
            capturePipeline.markAnalyzed(recordID: aggregate.recordShell.id)
        } catch {
            capturePipeline.markAnalysisUnavailable(
                recordID: aggregate.recordShell.id,
                detail: error.localizedDescription
            )
        }
    }

    @MainActor
    private func persistLocalChanges(recordID: UUID) -> Bool {
        do {
            try modelContext.save()
            capturePipeline.markSaved(recordID: recordID)
            return true
        } catch {
            let message = error.localizedDescription
            captureErrorMessage = message
            capturePipeline.markFailed(recordID: recordID, detail: message)
            return false
        }
    }

    @MainActor
    private func loadCurrentWeatherSnapshot(force: Bool) async {
        guard step == .weather else { return }
        if isFetchingWeatherSnapshot { return }
        if !force && weatherData.observedAt != nil { return }

        weatherFetchError = nil

        if !weatherService.hasUsableAuthorization() {
            weatherService.requestLocationPermission()
            weatherFetchError = t("add_card.weather.error.permission", "Allow location access to fill in current weather automatically")
            return
        }

        guard let location = weatherService.getCurrentLocation() else {
            weatherFetchError = t("add_card.weather.error.unavailable", "Current location is unavailable right now. Try again shortly.")
            return
        }

        isFetchingWeatherSnapshot = true
        defer { isFetchingWeatherSnapshot = false }

        do {
            weatherData = try await weatherService.fetchWeather(for: location)
        } catch {
            weatherFetchError = weatherService.errorMessage(for: error)
        }
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}
