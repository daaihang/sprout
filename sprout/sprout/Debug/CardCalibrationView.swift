import SwiftUI
import MapKit
import UIKit

struct CardCalibrationView: View {
    @State private var kind: DebugCardKind = .photo
    @State private var contentLevel: CalibrationContentLevel = .medium
    @State private var previewSpan: ContainerSpan = ContainerSpan(widthColumns: 4, heightUnits: 2)
    @State private var previewRotationDegrees: Double = 0
    @State private var previewThemePreset: AdaptiveCardThemePreset = .automatic
    @State private var previewMetricFont: AdaptiveCardFontFamily = .sfProRounded
    @State private var previewDensityChoice: CalibrationDensityChoice = .auto
    @State private var previewTransitionStyle: AdaptiveCardTransitionStyle = .standard
    @State private var previewDiagnostics: AdaptiveCardDiagnostics = .empty
    @State private var reviewNotes = ""
    @State private var copyStatusMessage: String?

    var body: some View {
        List {
            previewSection
            cardSection
            contentSection
            sizeSection
            styleSection
            diagnosticsSection
            notesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Card Calibration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    copyCalibrationSnapshot()
                } label: {
                    Label("Copy Snapshot", systemImage: "doc.on.doc")
                }
            }
        }
        .onChange(of: kind) { _, newKind in
            let limits = sizeLimits(for: newKind.gridCardType)
            previewSpan = limits.clamped(span: previewSpan)
        }
    }

    private var previewSection: some View {
        Section {
            CalibrationPreviewViewport(
                span: previewSpan,
                rotationDegrees: previewRotationDegrees,
                card: previewCard
            )
            .frame(height: 420)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        }
        .onPreferenceChange(AdaptiveCardDiagnosticsPreferenceKey.self) { previewDiagnostics = $0 }
    }

    private var cardSection: some View {
        Section("Card Type") {
            Picker("Card", selection: $kind) {
                ForEach(DebugCardKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
        }
    }

    private var contentSection: some View {
        Section("Content") {
            Picker("Density", selection: $contentLevel) {
                ForEach(CalibrationContentLevel.allCases) { level in
                    Text(level.label).tag(level)
                }
            }
            .pickerStyle(.segmented)

            Text(contentLevel.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var sizeSection: some View {
        Section("Size & Motion") {
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
            LabeledContent("Tilt", value: String(format: "%.1f°", previewRotationDegrees))

            Slider(value: $previewRotationDegrees, in: -12...12, step: 0.5)

            Button("Reset Calibration") {
                withAnimation(.spring(duration: 0.34, bounce: 0.14)) {
                    previewSpan = sizeLimits(for: kind.gridCardType).clamped(
                        span: ContainerSpan(widthColumns: 4, heightUnits: 2)
                    )
                    previewRotationDegrees = 0
                    previewThemePreset = .automatic
                    previewMetricFont = .sfProRounded
                    previewDensityChoice = .auto
                    previewTransitionStyle = .standard
                    contentLevel = .medium
                    reviewNotes = ""
                }
            }
        }
    }

    private var styleSection: some View {
        Section("Adaptive Style") {
            Picker("Theme", selection: $previewThemePreset) {
                ForEach(AdaptiveCardThemePreset.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }

            Picker("Density", selection: $previewDensityChoice) {
                ForEach(CalibrationDensityChoice.allCases) { choice in
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
        }
    }

    private var diagnosticsSection: some View {
        Section("Diagnostics") {
            LabeledContent("Layout Mode", value: previewDiagnostics.layoutMode)
            LabeledContent("Resolved Density", value: previewDiagnostics.density)
            LabeledContent("Theme", value: previewDiagnostics.theme)
            LabeledContent("Metric Font", value: previewDiagnostics.metricFont)
            LabeledContent("Title Overflow", value: previewDiagnostics.titleOverflow ? "Yes" : "No")
            LabeledContent("Subtitle Overflow", value: previewDiagnostics.subtitleOverflow ? "Yes" : "No")
            LabeledContent("Body Overflow", value: previewDiagnostics.bodyOverflow ? "Yes" : "No")
            LabeledContent("Visible List", value: previewDiagnostics.visibleListItems)
            LabeledContent("Hero Crop", value: previewDiagnostics.heroCrop)
            LabeledContent("Fallback", value: previewDiagnostics.fallbackReason)
        }
    }

    private var notesSection: some View {
        Section("Review Notes") {
            TextEditor(text: $reviewNotes)
                .frame(minHeight: 120)

            Button {
                copyCalibrationSnapshot()
            } label: {
                Label("Copy Snapshot", systemImage: "doc.on.doc")
            }

            if let copyStatusMessage {
                Text(copyStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("记录这个尺寸最终该保留什么，例如：只留标题 2 行，隐藏副标题和列表。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var previewTheme: AdaptiveCardTheme {
        previewThemePreset
            .makeTheme()
            .withMetricFamily(previewMetricFont)
            .withDensity(previewDensityChoice.density)
            .withTransitionStyle(previewTransitionStyle)
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

    private func availableWidths(for height: Int) -> [Int] {
        previewSizeLimits.allowedSpans
            .filter { $0.heightUnits == height }
            .map(\.widthColumns)
            .deduplicatedSorted()
            .sorted()
    }

    private func availableHeights(for width: Int) -> [Int] {
        previewSizeLimits.allowedSpans
            .filter { $0.widthColumns == width }
            .map(\.heightUnits)
            .deduplicatedSorted()
            .sorted()
    }

    private var previewCard: AnyView {
        AnyView(cardView.adaptiveCardTheme(previewTheme))
    }

    private var calibrationSnapshotText: String {
        """
        Card Calibration Snapshot
        Card Type: \(kind.title)
        Card Key: \(kind.gridCardType)
        Content Level: \(contentLevel.label)
        Size: \(previewSpan.widthColumns)x\(previewSpan.heightUnits)
        Tilt: \(String(format: "%.1f°", previewRotationDegrees))
        Theme: \(previewThemePreset.label)
        Metric Font: \(previewMetricFont.label)
        Density: \(previewDensityChoice.label)
        Motion: \(previewTransitionStyle.label)

        Diagnostics
        - Layout Mode: \(previewDiagnostics.layoutMode)
        - Resolved Density: \(previewDiagnostics.density)
        - Theme: \(previewDiagnostics.theme)
        - Metric Font: \(previewDiagnostics.metricFont)
        - Title Overflow: \(boolText(previewDiagnostics.titleOverflow))
        - Subtitle Overflow: \(boolText(previewDiagnostics.subtitleOverflow))
        - Body Overflow: \(boolText(previewDiagnostics.bodyOverflow))
        - Visible List: \(previewDiagnostics.visibleListItems)
        - Hero Crop: \(previewDiagnostics.heroCrop)
        - Fallback: \(previewDiagnostics.fallbackReason)

        Card Metadata
        \(previewCardMetadataDescription)

        Review Notes
        \(reviewNotes.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("-"))
        """
    }

    private var previewCardMetadataDescription: String {
        switch kind {
        case .quote:
            let data = CalibrationFixtures.quote(level: contentLevel)
            return """
            - quote: \(quotedOrDash(data.quote))
            - author: \(quotedOrDash(data.author))
            - source: \(quotedOrDash(data.source))
            """
        case .weather:
            let data = CalibrationFixtures.weather(level: contentLevel)
            return """
            - location: \(quotedOrDash(data.location))
            - temperature: \(data.temperature)
            - feelsLike: \(data.feelsLike)
            - condition: \(String(describing: data.condition))
            - humidity: \(data.humidity)
            - high: \(data.high)
            - low: \(data.low)
            - source: \(String(describing: data.source))
            - hasLiveData: \(boolText(data.liveData != nil))
            """
        case .link:
            let data = CalibrationFixtures.link(level: contentLevel)
            let titles = data.links.map { $0.title.isEmpty ? $0.domain : $0.title }.joined(separator: " | ").ifEmpty("-")
            return """
            - linkCount: \(data.links.count)
            - titles: \(titles)
            """
        case .activity:
            let data = CalibrationFixtures.activity(level: contentLevel)
            return """
            - type: \(String(describing: data.type))
            - value: \(data.value)
            - goal: \(data.goal)
            - durationMinutes: \(data.durationMinutes)
            """
        case .music:
            let data = CalibrationFixtures.music(level: contentLevel)
            return """
            - trackName: \(quotedOrDash(data.trackName))
            - artistName: \(quotedOrDash(data.artistName))
            - albumName: \(quotedOrDash(data.albumName))
            - isPlaying: \(boolText(data.isPlaying))
            - hasAppleMusicURL: \(boolText(data.appleMusicURL != nil))
            """
        case .emotion:
            let data = CalibrationFixtures.emotion(level: contentLevel)
            return """
            - mood: \(String(describing: data.mood))
            - intensity: \(data.intensity)
            - note: \(quotedOrDash(data.note))
            """
        case .todo:
            let data = CalibrationFixtures.todo(level: contentLevel)
            let items = data.items.map(\.text).joined(separator: " | ").ifEmpty("-")
            return """
            - title: \(quotedOrDash(data.title))
            - itemCount: \(data.items.count)
            - items: \(items)
            """
        case .photo:
            let data = CalibrationFixtures.photo(level: contentLevel)
            return """
            - imageCount: \(data.imagesData.count)
            - locationName: \(quotedOrDash(data.locationName))
            - descriptionText: \(quotedOrDash(data.descriptionText))
            - aiDescription: \(quotedOrDash(data.aiDescription))
            - trailingInfoText: \(quotedOrDash(data.trailingInfoText))
            """
        case .map:
            let data = CalibrationFixtures.map(level: contentLevel)
            return """
            - locationName: \(quotedOrDash(data.locationName))
            - descriptionText: \(quotedOrDash(data.descriptionText))
            - coordinate: \(coordinateDescription(data.coordinate))
            """
        case .audio:
            let data = CalibrationFixtures.audio(level: contentLevel)
            return """
            - title: \(quotedOrDash(data.title))
            - durationText: \(quotedOrDash(data.durationText))
            - transcriptPreview: \(quotedOrDash(data.transcriptPreview))
            - hasCapturedAt: \(boolText(data.capturedAt != nil))
            """
        case .people:
            let data = CalibrationFixtures.people(level: contentLevel)
            let names = data.people.map(\.name).joined(separator: " | ").ifEmpty("-")
            return """
            - peopleCount: \(data.people.count)
            - names: \(names)
            """
        case .todayInHistory:
            let data = CalibrationFixtures.todayInHistory(level: contentLevel)
            let summaries = data.entries.map { $0.record.body }.joined(separator: " | ").ifEmpty("-")
            return """
            - monthDayLabel: \(quotedOrDash(data.monthDayLabel))
            - entryCount: \(data.entries.count)
            - entryBodies: \(summaries)
            """
        case .book:
            let data = CalibrationFixtures.book(level: contentLevel)
            return """
            - title: \(quotedOrDash(data.title))
            - author: \(quotedOrDash(data.author))
            - progress: \(formattedProgress(data.progress))
            - genre: \(quotedOrDash(data.genre))
            - rating: \(data.rating.map(String.init) ?? "-")
            """
        case .film:
            let data = CalibrationFixtures.film(level: contentLevel)
            return """
            - title: \(quotedOrDash(data.title))
            - year: \(quotedOrDash(data.year))
            - genre: \(quotedOrDash(data.genre))
            - rating: \(data.rating.map { String(format: "%.1f", $0) } ?? "-")
            - director: \(quotedOrDash(data.director))
            - isWatched: \(boolText(data.isWatched))
            """
        }
    }

    private func copyCalibrationSnapshot() {
        UIPasteboard.general.string = calibrationSnapshotText
        copyStatusMessage = "Snapshot copied. Paste it here with your screenshot if needed."
    }

    private func boolText(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private func quotedOrDash(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "-" : trimmed
    }

    private func quotedOrDash(_ value: String?) -> String {
        guard let value else { return "-" }
        return quotedOrDash(value)
    }

    private func coordinateDescription(_ value: CLLocationCoordinate2D?) -> String {
        guard let value else { return "-" }
        return String(format: "%.4f, %.4f", value.latitude, value.longitude)
    }

    private func formattedProgress(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.2f", value)
    }

    @ViewBuilder
    private var cardView: some View {
        switch kind {
        case .quote:
            QuoteCard(data: CalibrationFixtures.quote(level: contentLevel))
        case .weather:
            WeatherCard(data: CalibrationFixtures.weather(level: contentLevel))
        case .link:
            LinkCard(data: CalibrationFixtures.link(level: contentLevel))
        case .activity:
            ActivityCard(data: CalibrationFixtures.activity(level: contentLevel))
        case .music:
            MusicCard(data: CalibrationFixtures.music(level: contentLevel))
        case .emotion:
            EmotionCard(data: CalibrationFixtures.emotion(level: contentLevel))
        case .todo:
            TodoCard(data: CalibrationFixtures.todo(level: contentLevel))
        case .photo:
            PhotoCard(data: CalibrationFixtures.photo(level: contentLevel))
        case .map:
            MapCard(data: CalibrationFixtures.map(level: contentLevel))
        case .audio:
            AudioCard(data: CalibrationFixtures.audio(level: contentLevel))
        case .people:
            PeopleCard(data: CalibrationFixtures.people(level: contentLevel))
        case .todayInHistory:
            TodayInHistoryCard(data: CalibrationFixtures.todayInHistory(level: contentLevel))
        case .book:
            BookCard(data: CalibrationFixtures.book(level: contentLevel))
        case .film:
            FilmCard(data: CalibrationFixtures.film(level: contentLevel))
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

private struct CalibrationPreviewViewport: View {
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
                    id: "calibration-preview-card",
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

private enum CalibrationContentLevel: String, CaseIterable, Identifiable {
    case short
    case medium
    case long

    var id: String { rawValue }

    var label: String {
        switch self {
        case .short: "Short"
        case .medium: "Medium"
        case .long: "Long"
        }
    }

    var description: String {
        switch self {
        case .short:
            "短内容，验证最简布局是否干净。"
        case .medium:
            "中等内容，验证默认尺寸下的主布局。"
        case .long:
            "极限长内容，验证字段取舍和降级是否正确。"
        }
    }
}

private enum CalibrationDensityChoice: String, CaseIterable, Identifiable {
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

private enum CalibrationFixtures {
    static func quote(level: CalibrationContentLevel) -> QuoteCardData {
        switch level {
        case .short:
            return QuoteCardData(
                quote: "Stay curious.",
                author: "Ada",
                source: "Notes"
            )
        case .medium:
            return QuoteCardData(
                quote: "We keep going not because the path is simple, but because motion itself reveals the next step.",
                author: "Maya Lin",
                source: "Studio Journal"
            )
        case .long:
            return QuoteCardData(
                quote: "When a day feels crowded and unresolved, the smallest deliberate act can still restore a sense of authorship over your own attention and time.",
                author: "Evelyn Hart",
                source: "Collected Fragments for Long Evenings"
            )
        }
    }

    static func weather(level: CalibrationContentLevel) -> WeatherCardData {
        switch level {
        case .short:
            return WeatherCardData(
                location: "Shanghai",
                temperature: 24,
                feelsLike: 25,
                condition: .sunny,
                humidity: 54,
                high: 27,
                low: 21
            )
        case .medium:
            return WeatherCardData(
                location: "Shanghai Xuhui",
                temperature: 18,
                feelsLike: 16,
                condition: .rainy,
                humidity: 84,
                high: 20,
                low: 15,
                observedAt: Date()
            )
        case .long:
            return WeatherCardData(
                location: "Shanghai Pudong Riverside Greenway",
                temperature: 4,
                feelsLike: -1,
                condition: .windy,
                humidity: 91,
                high: 8,
                low: 2,
                observedAt: Date(),
                source: .manual,
                liveData: LiveWeatherData(temperature: 4, condition: .windy, fetchedAt: Date())
            )
        }
    }

    static func link(level: CalibrationContentLevel) -> LinkCardData {
        switch level {
        case .short:
            return LinkCardData(links: [
                LinkItem(url: URL(string: "https://openai.com")!, title: "OpenAI", description: "", iconURL: nil)
            ])
        case .medium:
            return LinkCardData(links: [
                LinkItem(url: URL(string: "https://developer.apple.com")!, title: "Apple Developer", description: "Human Interface Guidelines and platform design resources.", iconURL: nil),
                LinkItem(url: URL(string: "https://swift.org")!, title: "Swift", description: "Language updates and evolution discussions.", iconURL: nil)
            ])
        case .long:
            return LinkCardData(links: [
                LinkItem(url: URL(string: "https://developer.apple.com/design/")!, title: "Apple Design Resources", description: "Interface kits, typography, SF Symbols, and design videos for building cohesive platform experiences.", iconURL: nil),
                LinkItem(url: URL(string: "https://swift.org")!, title: "Swift Evolution Process", description: "Proposal reviews, accepted changes, and upcoming language directions.", iconURL: nil),
                LinkItem(url: URL(string: "https://developer.apple.com/documentation/swiftui")!, title: "SwiftUI Documentation", description: "Framework documentation, samples, and latest APIs.", iconURL: nil),
                LinkItem(url: URL(string: "https://forums.swift.org")!, title: "Swift Forums", description: "Design rationale, compiler notes, and community discussions.", iconURL: nil),
                LinkItem(url: URL(string: "https://www.figma.com")!, title: "Figma Workspace", description: "Shared UI explorations and layout references.", iconURL: nil),
            ])
        }
    }

    static func activity(level: CalibrationContentLevel) -> ActivityCardData {
        switch level {
        case .short:
            return ActivityCardData(type: .steps, value: 3280, goal: 0, durationMinutes: 18)
        case .medium:
            return ActivityCardData(type: .running, value: 6.8, goal: 10, durationMinutes: 42)
        case .long:
            return ActivityCardData(type: .workout, value: 84, goal: 120, durationMinutes: 96)
        }
    }

    static func music(level: CalibrationContentLevel) -> MusicCardData {
        switch level {
        case .short:
            return MusicCardData(
                trackName: "Bloom",
                artistName: "Odesza",
                albumName: "",
                isPlaying: false
            )
        case .medium:
            return MusicCardData(
                trackName: "Motion Picture Soundtrack",
                artistName: "Radiohead",
                albumName: "Kid A",
                appleMusicURL: URL(string: "https://music.apple.com"),
                isPlaying: true
            )
        case .long:
            return MusicCardData(
                trackName: "The Place Where He Inserted the Blade",
                artistName: "Black Country, New Road",
                albumName: "Ants From Up There (Deluxe Edition)",
                appleMusicURL: URL(string: "https://music.apple.com"),
                isPlaying: true
            )
        }
    }

    static func emotion(level: CalibrationContentLevel) -> EmotionCardData {
        switch level {
        case .short:
            return EmotionCardData(mood: .calm, note: "", intensity: 2)
        case .medium:
            return EmotionCardData(mood: .grateful, note: "A quiet dinner and one unexpectedly kind message changed the tone of the whole evening.", intensity: 4)
        case .long:
            return EmotionCardData(mood: .anxious, note: "Too many parallel tasks, too little closure, and the feeling that every unfinished detail is still asking for attention at once.", intensity: 5)
        }
    }

    static func todo(level: CalibrationContentLevel) -> TodoCardData {
        switch level {
        case .short:
            return TodoCardData(
                title: "Today",
                items: [
                    TodoItem(text: "Reply to Alex", isDone: false),
                    TodoItem(text: "Water plants", isDone: true),
                ]
            )
        case .medium:
            return TodoCardData(
                title: "Launch Prep",
                items: [
                    TodoItem(text: "Finalize onboarding copy", isDone: true),
                    TodoItem(text: "Recheck settings state restoration", isDone: false),
                    TodoItem(text: "Confirm analytics event names", isDone: false),
                    TodoItem(text: "Ship build to TestFlight", isDone: false),
                ]
            )
        case .long:
            return TodoCardData(
                title: "Release Checklist",
                items: [
                    TodoItem(text: "Review edge cases for dynamic type and long localization", isDone: false),
                    TodoItem(text: "Audit card truncation behavior across all supported spans", isDone: false),
                    TodoItem(text: "Confirm error copy for permissions and offline flows", isDone: true),
                    TodoItem(text: "Record final walkthrough video", isDone: false),
                    TodoItem(text: "Send stakeholder summary", isDone: false),
                    TodoItem(text: "Archive previous milestone notes", isDone: true),
                ]
            )
        }
    }

    static func photo(level: CalibrationContentLevel) -> PhotoCardData {
        switch level {
        case .short:
            return PhotoCardData(
                imagesData: [makePhotoData(colors: [.systemOrange, .systemPink])],
                locationName: "Wukang Rd",
                descriptionText: "",
                aiDescription: "Late afternoon light",
                trailingInfoText: "03"
            )
        case .medium:
            return PhotoCardData(
                imagesData: [makePhotoData(colors: [.systemBlue, .systemTeal])],
                locationName: "West Bund Riverside",
                descriptionText: "Cyclists passed in silhouette while the river turned silver under the clouds.",
                aiDescription: "Riverside before rain",
                trailingInfoText: "12"
            )
        case .long:
            return PhotoCardData(
                imagesData: [makePhotoData(colors: [.systemIndigo, .black])],
                locationName: "Shanghai Natural History Museum South Plaza",
                descriptionText: "A crowded, reflective scene with umbrellas, moving traffic, layered glass, and a lot of competing visual detail in the frame.",
                aiDescription: "Dense rainy-city moment with reflections and moving people",
                trailingInfoText: "24"
            )
        }
    }

    static func map(level: CalibrationContentLevel) -> MapCardData {
        switch level {
        case .short:
            return MapCardData(
                coordinate: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
                locationName: "People's Square",
                descriptionText: ""
            )
        case .medium:
            return MapCardData(
                coordinate: CLLocationCoordinate2D(latitude: 31.2186, longitude: 121.4458),
                locationName: "Xuhui Riverside",
                descriptionText: "Evening walk"
            )
        case .long:
            return MapCardData(
                coordinate: CLLocationCoordinate2D(latitude: 31.2243, longitude: 121.4692),
                locationName: "Shanghai Conservatory area",
                descriptionText: "Long detour after work with multiple stops, photos, and notes tied to the same route."
            )
        }
    }

    static func audio(level: CalibrationContentLevel) -> AudioCardData {
        switch level {
        case .short:
            return AudioCardData(
                title: "Idea",
                audioData: makeSampleAudioData(duration: 1.2, frequency: 520),
                transcriptPreview: "",
                durationText: "00:01"
            )
        case .medium:
            return AudioCardData(
                title: "Morning Walk Note",
                audioData: makeSampleAudioData(duration: 4.8, frequency: 700),
                transcriptPreview: "The light was very soft today and I want the home page to feel that calm but still slightly structured.",
                durationText: "00:05",
                capturedAt: Date()
            )
        case .long:
            return AudioCardData(
                title: "Longer Reflection After Review Session",
                audioData: makeSampleAudioData(duration: 12.4, frequency: 760),
                transcriptPreview: "I think the main issue is not just information density, but the fact that the hierarchy keeps changing when the card shrinks, so the user loses the one stable anchor they should still be able to scan first.",
                durationText: "00:12",
                capturedAt: Date()
            )
        }
    }

    static func people(level: CalibrationContentLevel) -> PeopleCardData {
        switch level {
        case .short:
            return PeopleCardData(people: [
                PersonCardItem(name: "Alice", nickname: "Al", relationship: "Friend", mentionCount: 3)
            ])
        case .medium:
            return PeopleCardData(people: [
                PersonCardItem(name: "Alice Chen", nickname: "Al", relationship: "Friend", mentionCount: 8),
                PersonCardItem(name: "Marcus Lin", relationship: "Teammate", mentionCount: 5),
                PersonCardItem(name: "Nina", relationship: "Designer", mentionCount: 2),
            ])
        case .long:
            return PeopleCardData(people: [
                PersonCardItem(name: "Alice Chen", nickname: "Al", relationship: "Long-time friend", mentionCount: 12),
                PersonCardItem(name: "Marcus Lin", relationship: "Product teammate", mentionCount: 8),
                PersonCardItem(name: "Nina Park", relationship: "Visual designer", mentionCount: 5),
                PersonCardItem(name: "Joseph Stone", relationship: "Research collaborator", mentionCount: 4),
                PersonCardItem(name: "Mika", relationship: "Photographer", mentionCount: 3),
            ])
        }
    }

    static func todayInHistory(level: CalibrationContentLevel) -> TodayInHistoryCardData {
        let year = Calendar.current.component(.year, from: Date())
        let count: Int
        switch level {
        case .short: count = 2
        case .medium: count = 4
        case .long: count = 6
        }

        let records = (0..<count).map { index -> Record in
            let record = Record()
            record.createdAt = Calendar.current.date(byAdding: .year, value: -(index + 1), to: Date()) ?? Date()
            record.body = [
                "Found a quiet street after the rain.",
                "Finished a draft and finally relaxed.",
                "Took photos by the river at sunset.",
                "Met an old friend for noodles and a long talk.",
                "Stayed up too late tuning small UI details.",
                "Walked home listening to the same album twice."
            ][index]
            record.cardType = "text"
            return record
        }

        return TodayInHistoryCardData(
            monthDayLabel: "May 13",
            entries: records.map { TodayInHistoryEntry(record: $0, referenceYear: year) }
        )
    }

    static func book(level: CalibrationContentLevel) -> BookCardData {
        switch level {
        case .short:
            return BookCardData(
                title: "Orbiting",
                author: "R. Lee",
                progress: 0.22
            )
        case .medium:
            return BookCardData(
                title: "The Left Hand of Darkness",
                author: "Ursula K. Le Guin",
                progress: 0.64,
                genre: "Science Fiction",
                rating: 5
            )
        case .long:
            return BookCardData(
                title: "A Swim in a Pond in the Rain",
                author: "George Saunders",
                progress: 0.91,
                genre: "Writing, Fiction, Literary Criticism",
                rating: 5
            )
        }
    }

    static func film(level: CalibrationContentLevel) -> FilmCardData {
        switch level {
        case .short:
            return FilmCardData(
                title: "Past Lives",
                year: "2023",
                isWatched: true
            )
        case .medium:
            return FilmCardData(
                title: "Decision to Leave",
                year: "2022",
                genre: "Mystery / Romance",
                rating: 4.5,
                director: "Park Chan-wook",
                isWatched: true
            )
        case .long:
            return FilmCardData(
                title: "The Assassination of Jesse James by the Coward Robert Ford",
                year: "2007",
                genre: "Western / Drama / Character Study",
                rating: 4.7,
                director: "Andrew Dominik",
                isWatched: false
            )
        }
    }

    private static func makePhotoData(colors: [UIColor]) -> Data {
        let size = CGSize(width: 1200, height: 900)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgColors = colors.map(\.cgColor) as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: [0, 1])!
            let rect = CGRect(origin: .zero, size: size)

            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            context.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.18).cgColor)
            context.cgContext.fillEllipse(in: rect.insetBy(dx: 110, dy: 120))
            context.cgContext.setFillColor(UIColor.black.withAlphaComponent(0.12).cgColor)
            context.cgContext.fill(CGRect(x: 0, y: size.height * 0.64, width: size.width, height: size.height * 0.36))
        }

        return image.jpegData(compressionQuality: 0.88) ?? Data()
    }
}

private extension Array where Element: Hashable {
    func deduplicatedSorted() -> [Element] {
        Array(Set(self))
    }
}

#Preview {
    NavigationStack {
        CardCalibrationView()
    }
}
