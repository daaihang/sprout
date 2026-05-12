import SwiftUI
import PhotosUI
import MapKit
import MusicKit
import SwiftData

struct CardDebugView: View {
    @Environment(AppLocalization.self) var localization
    @Environment(\.modelContext) var modelContext
    @Query(sort: \DashboardSystemCardConfig.dashboardOrder, order: .forward) var systemConfigs: [DashboardSystemCardConfig]

    let kind: DebugCardKind

    @State var previewSpan: ContainerSpan
    @State var previewRotationDegrees: Double
    @State private var previewThemePreset: AdaptiveCardThemePreset = .automatic
    @State private var previewMetricFont: AdaptiveCardFontFamily = .sfProRounded
    @State private var previewDensityChoice: AdaptiveCardDebugDensityChoice = .auto
    @State private var previewTransitionStyle: AdaptiveCardTransitionStyle = .standard
    @State private var previewDiagnostics: AdaptiveCardDiagnostics = .empty

    @State var photoData = PhotoCardData()
    @State var selectedPhotoItems: [PhotosPickerItem] = []
    @State var isLoadingImages = false

    @State var mapData = MapCardData()
    @State var isShowingMapSheet = false

    @State var linkData = LinkCardData()
    @State var newLinkURL = ""
    @State var newLinkTitle = ""
    @State var newLinkDescription = ""

    @State var musicData = MusicCardData()
    @State var isShowingMusicSheet = false
    @State var musicService = MusicService()

    @State var quoteData = QuoteCardData()
    @State var weatherData = WeatherCardData()
    @State var weatherService = WeatherDataService()
    @State var isFetchingWeather = false
    @State var activityData = ActivityCardData()
    @State var emotionData: EmotionCardData? = nil
    @State var todoData = TodoCardData()
    @State var newTodoText = ""
    @State var bookData = BookCardData()
    @State var filmData = FilmCardData()
    @State var audioData = AudioCardData(
        title: "晨间散步录音",
        audioData: makeSampleAudioData(),
        transcriptPreview: "今天的风很轻，路边的树影在晃，突然觉得这个早晨很值得被记住。",
        durationText: "00:02"
    )
    @State var peopleData = PeopleCardData(
        people: [
            PersonCardItem(name: "Alice", nickname: "A", relationship: "Friend", mentionCount: 8),
            PersonCardItem(name: "Bob", relationship: "Colleague", mentionCount: 5),
        ]
    )
    @State var newPersonName = ""
    @State var newPersonNickname = ""
    @State var newPersonRelationship = ""
    @State var todayInHistoryData = TodayInHistoryCardData(monthDayLabel: "May 11", entries: [])

    init(kind: DebugCardKind) {
        self.kind = kind
        let defaultSpan = sizeLimits(for: kind.gridCardType).clamped(
            span: ContainerSpan(widthColumns: 4, heightUnits: 4)
        )
        _previewSpan = State(initialValue: defaultSpan)
        _previewRotationDegrees = State(initialValue: 0)
    }

    var body: some View {
        List {
            previewSection
            previewControlsSection
            previewStyleSection
            controlsContent
        }
        .listStyle(.insetGrouped)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if kind == .todayInHistory && todayInHistoryData.entries.isEmpty {
                todayInHistoryData = makeTodayInHistorySample(entryCount: 3)
            }
        }
        .sheet(isPresented: $isShowingMapSheet) {
            MapCardSheet(data: $mapData)
        }
        .sheet(isPresented: $isShowingMusicSheet) {
            MusicCardSheet(data: $musicData, musicService: musicService)
        }
    }

    private var previewSection: some View {
        Section {
            DebugCardPreviewViewport(
                span: previewSpan,
                rotationDegrees: previewRotationDegrees,
                card: previewCard
            )
            .frame(height: 420)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        }
        .onPreferenceChange(AdaptiveCardDiagnosticsPreferenceKey.self) { previewDiagnostics = $0 }
    }

    private var previewControlsSection: some View {
        Section("Preview Controls") {
            Picker("Width", selection: previewWidthBinding) {
                ForEach(availableWidths(for: previewSpan.heightUnits), id: \.self) { width in
                    Text("\(width)").tag(width)
                }
            }
            .pickerStyle(.segmented)

            Picker("Height", selection: previewHeightBinding) {
                ForEach(availableHeights(for: previewSpan.widthColumns), id: \.self) { height in
                    Text("\(height)").tag(height)
                }
            }
            .pickerStyle(.segmented)

            LabeledContent("Current Size", value: "\(previewSpan.widthColumns) × \(previewSpan.heightUnits)")

            LabeledContent("Tilt") {
                Text(String(format: "%.1f°", previewRotationDegrees))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(value: $previewRotationDegrees, in: -12...12, step: 0.5)

            Button("Reset Preview") {
                withAnimation(.spring(duration: 0.34, bounce: 0.14)) {
                    previewSpan = previewSizeLimits.clamped(span: ContainerSpan(widthColumns: 4, heightUnits: 4))
                    previewRotationDegrees = 0
                    previewThemePreset = .automatic
                    previewMetricFont = .sfProRounded
                    previewDensityChoice = .auto
                    previewTransitionStyle = .standard
                }
            }
        }
    }

    private var previewStyleSection: some View {
        Section("Adaptive Style") {
            Picker("Theme", selection: $previewThemePreset) {
                ForEach(AdaptiveCardThemePreset.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }

            Picker("Density", selection: $previewDensityChoice) {
                ForEach(AdaptiveCardDebugDensityChoice.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            .pickerStyle(.segmented)

            Picker("Metric Font", selection: $previewMetricFont) {
                ForEach(AdaptiveCardFontFamily.allCases) { family in
                    Text(family.label).tag(family)
                }
            }

            Picker("Motion", selection: $previewTransitionStyle) {
                ForEach(AdaptiveCardTransitionStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }
            .pickerStyle(.segmented)

            LabeledContent("Layout Mode", value: previewDiagnostics.layoutMode)
            LabeledContent("Resolved Density", value: previewDiagnostics.density)
            LabeledContent("Metric Font", value: previewDiagnostics.metricFont)
            LabeledContent("Theme", value: previewDiagnostics.theme)
            LabeledContent("Title Overflow", value: previewDiagnostics.titleOverflow ? "Yes" : "No")
            LabeledContent("Subtitle Overflow", value: previewDiagnostics.subtitleOverflow ? "Yes" : "No")
            LabeledContent("Body Overflow", value: previewDiagnostics.bodyOverflow ? "Yes" : "No")
            LabeledContent("Visible List", value: previewDiagnostics.visibleListItems)
            LabeledContent("Hero Crop", value: previewDiagnostics.heroCrop)
            LabeledContent("Fallback", value: previewDiagnostics.fallbackReason)
        }
    }

    @ViewBuilder
    var controlsContent: some View {
        switch kind {
        case .photo:
            photoControlsSections
        case .map:
            mapControlsSections
        case .link:
            linkControlsSections
        case .music:
            musicControlsSections
        case .quote:
            quoteControlsSections
        case .weather:
            weatherControlsSections
        case .activity:
            activityControlsSections
        case .emotion:
            emotionControlsSections
        case .todo:
            todoControlsSections
        case .audio:
            audioControlsSections
        case .people:
            peopleControlsSections
        case .todayInHistory:
            todayInHistoryControlsSections
        case .book:
            bookControlsSections
        case .film:
            filmControlsSections
        }
    }

    var previewItems: [GridItem] {
        [
            previewItem(columns: previewSpan.widthColumns, units: previewSpan.heightUnits) {
                previewCard
            }
        ]
    }

    func previewItem(columns: Int, units: Int, card: () -> AnyView) -> GridItem {
        GridItem(
            id: "\(kind.rawValue)-preview",
            card: card(),
            columns: columns,
            units: units,
            rotationDegrees: previewRotationDegrees,
            scale: 1,
            availableSpans: availableSpans(for: kind.gridCardType)
        )
    }

    private var previewCard: AnyView {
        let card: AnyView
        switch kind {
        case .photo:
            card = AnyView(PhotoCard(data: photoData))
        case .map:
            card = AnyView(MapCard(data: mapData, onTap: { isShowingMapSheet = true }))
        case .link:
            card = AnyView(LinkCard(data: linkData))
        case .music:
            card = AnyView(MusicCard(data: musicData.isEmpty ? nil : musicData, onTap: { isShowingMusicSheet = true }))
        case .quote:
            card = AnyView(QuoteCard(data: quoteData.isEmpty ? nil : quoteData))
        case .weather:
            card = AnyView(WeatherCard(data: weatherData.isEmpty ? nil : weatherData))
        case .activity:
            card = AnyView(ActivityCard(data: activityData.isEmpty ? nil : activityData))
        case .emotion:
            card = AnyView(EmotionCard(data: emotionData))
        case .todo:
            card = AnyView(TodoCard(data: todoData.isEmpty ? nil : todoData))
        case .audio:
            card = AnyView(AudioCard(data: audioData.isEmpty ? nil : audioData))
        case .people:
            card = AnyView(PeopleCard(data: peopleData.isEmpty ? nil : peopleData))
        case .todayInHistory:
            card = AnyView(TodayInHistoryCard(data: todayInHistoryData.isEmpty ? nil : todayInHistoryData))
        case .book:
            card = AnyView(BookCard(data: bookData.isEmpty ? nil : bookData))
        case .film:
            card = AnyView(FilmCard(data: filmData.isEmpty ? nil : filmData))
        }

        return AnyView(card.adaptiveCardTheme(previewTheme))
    }

    private var previewSizeLimits: CardSizeLimits {
        sizeLimits(for: kind.gridCardType)
    }

    private var previewWidthBinding: Binding<Int> {
        Binding(
            get: { previewSpan.widthColumns },
            set: { previewSpan = previewSizeLimits.clamped(span: ContainerSpan(widthColumns: $0, heightUnits: previewSpan.heightUnits)) }
        )
    }

    private var previewHeightBinding: Binding<Int> {
        Binding(
            get: { previewSpan.heightUnits },
            set: { previewSpan = previewSizeLimits.clamped(span: ContainerSpan(widthColumns: previewSpan.widthColumns, heightUnits: $0)) }
        )
    }

    func availableWidths(for height: Int) -> [Int] {
        previewSizeLimits.allowedSpans
            .filter { $0.heightUnits == height }
            .map(\.widthColumns)
            .deduplicatedSorted()
            .sorted()
    }

    func availableHeights(for width: Int) -> [Int] {
        previewSizeLimits.allowedSpans
            .filter { $0.widthColumns == width }
            .map(\.heightUnits)
            .deduplicatedSorted()
            .sorted()
    }

    func allowedWidthBinding(for object: DashboardSystemCardConfig) -> Binding<Int> {
        Binding(
            get: {
                if availableWidths(for: object.heightUnits).contains(object.widthColumns) {
                    return object.widthColumns
                }
                return sizeLimits(for: DashboardSystemCardConfig.todayInHistoryKind)
                    .clamped(span: object.span)
                    .widthColumns
            },
            set: { object.widthColumns = $0 }
        )
    }

    var todayInHistorySystemConfig: DashboardSystemCardConfig? {
        systemConfigs.first(where: { $0.kind == DashboardSystemCardConfig.todayInHistoryKind })
    }

    func createTodayInHistorySystemConfig() {
        let config = DashboardSystemCardConfig(
            kind: DashboardSystemCardConfig.todayInHistoryKind,
            isEnabled: true,
            widthColumns: 4,
            heightUnits: 4,
            dashboardOrder: -10_000
        )
        modelContext.insert(config)
    }

    func binding<Value>(
        for object: DashboardSystemCardConfig,
        keyPath: ReferenceWritableKeyPath<DashboardSystemCardConfig, Value>
    ) -> Binding<Value> {
        Binding(
            get: { object[keyPath: keyPath] },
            set: { object[keyPath: keyPath] = $0 }
        )
    }

    func allowedHeightBinding(for object: DashboardSystemCardConfig) -> Binding<Int> {
        Binding(
            get: {
                if availableHeights(for: object.widthColumns).contains(object.heightUnits) {
                    return object.heightUnits
                }
                return sizeLimits(for: DashboardSystemCardConfig.todayInHistoryKind)
                    .clamped(span: object.span)
                    .heightUnits
            },
            set: { object.heightUnits = $0 }
        )
    }

    func makeTodayInHistorySample(entryCount: Int) -> TodayInHistoryCardData {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let records = (0..<entryCount).map { index -> Record in
            let record = Record()
            let yearsAgo = index + 1
            record.createdAt = calendar.date(byAdding: .year, value: -yearsAgo, to: Date()) ?? Date()
            record.body = [
                "那天在公园里拍到了很好看的光影。",
                "第一次去了新的咖啡馆，记住了窗边的位置。",
                "和老朋友散步，聊了很久。",
                "完成了一个重要项目，晚上吃了庆祝晚餐。",
                "在路上听到喜欢的歌，突然很开心。",
                "整理旧照片时想起了很多事情。",
            ][index % 6]
            record.cardType = "text"
            return record
        }

        return TodayInHistoryCardData(
            monthDayLabel: "May 11",
            entries: records.map { TodayInHistoryEntry(record: $0, referenceYear: currentYear) }
        )
    }

    func addTodoItem() {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation { todoData.items.append(TodoItem(text: trimmed)) }
        newTodoText = ""
    }

    var musicAuthStatusText: String {
        switch musicService.authorizationStatus {
        case .authorized: return t("common.musickit.authorized", "MusicKit Authorized")
        case .denied: return t("common.musickit.denied", "MusicKit Denied")
        case .notDetermined: return t("common.musickit.not_determined", "MusicKit Not Authorized")
        case .restricted: return t("common.musickit.restricted", "MusicKit Restricted")
        @unknown default: return t("common.musickit.unknown", "MusicKit Unknown")
        }
    }

    var musicAuthStatusIcon: String {
        switch musicService.authorizationStatus {
        case .authorized: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    var musicAuthStatusColor: Color {
        switch musicService.authorizationStatus {
        case .authorized: return .green
        case .denied: return .red
        default: return .orange
        }
    }

    func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }

    private var previewTheme: AdaptiveCardTheme {
        previewThemePreset
            .makeTheme()
            .withMetricFamily(previewMetricFont)
            .withDensity(previewDensityChoice.density)
            .withTransitionStyle(previewTransitionStyle)
    }
}

private struct DebugCardPreviewViewport: View {
    let span: ContainerSpan
    let rotationDegrees: Double
    let card: AnyView

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(geometry.size.width, 240)
            let unitWidth = GridConfig.unitWidth(screenWidth: availableWidth)
            let cardSize = span.size(unitWidth: unitWidth)

            CardContainerView(
                container: CardContainer(
                    id: "debug-preview-card",
                    span: span,
                    rotationDegrees: rotationDegrees,
                    scale: 1,
                    zIndex: 0,
                    content: card
                )
            )
            .frame(width: cardSize.width, height: cardSize.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .animation(.spring(duration: 0.42, bounce: 0.16), value: span)
            .animation(.spring(duration: 0.32, bounce: 0.08), value: rotationDegrees)
        }
    }
}

private extension Array where Element: Hashable {
    func deduplicatedSorted() -> [Element] {
        Array(Set(self))
    }
}

#Preview {
    NavigationStack {
        CardDebugView(kind: .photo)
    }
}

private enum AdaptiveCardDebugDensityChoice: String, CaseIterable, Identifiable {
    case auto
    case compact
    case standard
    case relaxed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: "Auto"
        case .compact: "Compact"
        case .standard: "Standard"
        case .relaxed: "Relaxed"
        }
    }

    var density: AdaptiveCardDensity? {
        switch self {
        case .auto: nil
        case .compact: .compact
        case .standard: .standard
        case .relaxed: .relaxed
        }
    }
}
