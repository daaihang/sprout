import SwiftUI
import SwiftData
import UIKit

struct RecordTimelineView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.modelContext) private var modelContext

    let selectedDate: Date

    @State private var hasPerformedInitialScroll = false
    @State private var records: [Record] = []
    @State private var fetchLimit = 120
    @State private var isLoadingMore = false

    private let fetchBatchSize = 120

    private var daySections: [RecordDaySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.createdAt)
        }

        return grouped
            .map { date, records in
                RecordDaySection(
                    id: date,
                    records: records.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { $0.id > $1.id }
    }

    private var sectionIDs: [Double] {
        daySections.map { $0.id.timeIntervalSinceReferenceDate }
    }

    var body: some View {
        Group {
            if daySections.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 120)
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(daySections) { section in
                            Section(sectionTitle(for: section.id)) {
                                ForEach(Array(section.records.enumerated()), id: \.element.id) { index, record in
                                    RecordTimelineRow(record: record)
                                        .id(record.id)
                                        .task {
                                            await loadMoreIfNeeded(currentRecord: record, sectionIndex: index)
                                        }
                                }
                            }
                            .id(sectionAnchorID(for: section))
                        }
                    }
                    .listStyle(.insetGrouped)
                    .contentMargins(.bottom, 104, for: .scrollContent)
                    .task(id: sectionIDs) {
                        guard !hasPerformedInitialScroll, !daySections.isEmpty else { return }
                        hasPerformedInitialScroll = true
                        await scroll(to: selectedDate, using: proxy, animated: false)
                    }
                    .onChange(of: selectedDate) { _, newValue in
                        Task {
                            await ensureVisibleWindow(for: newValue)
                            await scroll(to: newValue, using: proxy, animated: true)
                        }
                    }
                }
            }
        }
        .background(Color.clear)
        .task {
            await reloadRecords()
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            Task {
                await reloadRecords()
            }
        }
    }

    @MainActor
    private func reloadRecords() async {
        records = fetchRecords(limit: fetchLimit)
    }

    @MainActor
    private func ensureVisibleWindow(for date: Date) async {
        let targetDay = Calendar.current.startOfDay(for: date)
        guard !records.isEmpty else {
            await reloadRecords()
            return
        }

        while !records.isEmpty,
              records.last?.createdAt ?? .distantPast > targetDay,
              hasMoreRecords
        {
            fetchLimit += fetchBatchSize
            records = fetchRecords(limit: fetchLimit)
        }
    }

    @MainActor
    private func loadMoreIfNeeded(currentRecord: Record, sectionIndex: Int) async {
        guard !isLoadingMore,
              hasMoreRecords,
              isNearWindowEnd(record: currentRecord, sectionIndex: sectionIndex)
        else {
            return
        }

        isLoadingMore = true
        fetchLimit += fetchBatchSize
        records = fetchRecords(limit: fetchLimit)
        isLoadingMore = false
    }

    private func isNearWindowEnd(record: Record, sectionIndex: Int) -> Bool {
        guard let lastSection = daySections.last else { return false }
        guard Calendar.current.isDate(lastSection.id, inSameDayAs: Calendar.current.startOfDay(for: record.createdAt)) else {
            return false
        }
        return sectionIndex >= max(lastSection.records.count - 12, 0)
    }

    private var hasMoreRecords: Bool {
        records.count >= fetchLimit
    }

    private func fetchRecords(limit: Int) -> [Record] {
        var descriptor = FetchDescriptor<Record>(
            sortBy: [SortDescriptor(\Record.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func scroll(to date: Date, using proxy: ScrollViewProxy, animated: Bool) async {
        guard let target = targetScrollID(for: date) else { return }

        try? await Task.sleep(for: .milliseconds(50))
        await MainActor.run {
            if animated {
                withAnimation(.spring(duration: 0.32, bounce: 0.08)) {
                    proxy.scrollTo(target, anchor: .top)
                }
            } else {
                proxy.scrollTo(target, anchor: .top)
            }
        }
    }

    private func targetScrollID(for requestedDate: Date) -> String? {
        guard !daySections.isEmpty else { return nil }

        let targetDay = Calendar.current.startOfDay(for: requestedDate)
        if let exactSection = daySections.first(where: { Calendar.current.isDate($0.id, inSameDayAs: targetDay) }) {
            return sectionAnchorID(for: exactSection)
        }

        return daySections.min {
            abs($0.id.timeIntervalSince(targetDay)) < abs($1.id.timeIntervalSince(targetDay))
        }.map(sectionAnchorID(for:))
    }

    private func sectionAnchorID(for section: RecordDaySection) -> String {
        "record-day-\(section.id.timeIntervalSinceReferenceDate)"
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.secondary.opacity(0.45))

            Text(localization.string("timeline.empty.title", default: "No records yet"))
                .font(.headline)
                .foregroundStyle(.primary)

            Text(localization.string("timeline.empty.subtitle", default: "Records you create from the composer and quick-add flows will appear here in chronological order."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if calendar.isDate(date, inSameDayAs: today) {
            return localization.string("content.date.today", default: "Today")
        }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        if calendar.isDate(date, inSameDayAs: yesterday) {
            return localization.string("content.date.yesterday", default: "Yesterday")
        }

        return localization.templateDateString(from: date, template: "MMM d EEEE")
    }
}

struct RecordDaySection: Identifiable {
    let id: Date
    let records: [Record]
}

struct RecordTimelineRow: View {
    @Environment(AppLocalization.self) private var localization

    let record: Record

    var body: some View {
        NavigationLink(
            destination: RecordDetailView(
                record: record,
                focusedSection: preferredFocusedSection
            )
        ) {
            HStack(alignment: .top, spacing: 14) {
                preview

                VStack(alignment: .leading, spacing: 6) {
                    Text(timeLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Text(headlineText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    if let supportingText, !supportingText.isEmpty {
                        Text(supportingText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }

                    if !metaLine.isEmpty {
                        Text(metaLine)
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.85))
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
    }

    private var preferredFocusedSection: RecordSection {
        if !record.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text
        }

        switch record.cardKind {
        case .photo:
            return .photo
        case .music:
            return .music
        case .audio:
            return .audio
        case .todo:
            return .todo
        case .link:
            return .link
        case .map:
            return .map
        case .activity:
            return .activity
        case .emotion:
            return .emotion
        case .weather:
            return .weather
        case .people:
            return .people
        case .text, .quote, .todayInHistory, .book, .film, .game, .ticket, .health:
            return .text
        }
    }

    @ViewBuilder
    private var preview: some View {
        if record.cardKind == .photo, let image = photoPreviewImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else if record.cardKind == .emotion, let mood = MoodType(rawValue: record.mood ?? "") {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(mood.color.opacity(0.16))
                .frame(width: 62, height: 62)
                .overlay(
                    Text(mood.emoji)
                        .font(.system(size: 30))
                )
        } else if record.cardKind == .people, let person = record.mentionedPeople?.first {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.14))
                .frame(width: 62, height: 62)
                .overlay(
                    Text(person.initials)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                )
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(previewTint.opacity(0.14))
                .frame(width: 62, height: 62)
                .overlay(
                    Image(systemName: previewSymbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(previewTint)
                )
        }
    }

    private var previewSymbol: String {
        switch record.cardKind {
        case .weather:
            return (record.weather).flatMap(WeatherCondition.init(rawValue:))?.sfSymbol ?? record.cardKind.timelineSymbolName
        default:
            return record.cardKind.timelineSymbolName
        }
    }

    private var previewTint: Color {
        switch record.cardKind {
        case .weather:
            return (record.weather).flatMap(WeatherCondition.init(rawValue:))?.color ?? .accentColor
        case .audio:
            return .orange
        case .music:
            return .pink
        case .map:
            return .green
        case .todo:
            return .accentColor
        case .link:
            return .blue
        default:
            return .accentColor
        }
    }

    private var photoPreviewImage: UIImage? {
        let photoMedia = (record.mediaCards ?? []).first(where: { $0.mediaKind == .photo })
        if let data = photoMedia?.thumbnailData ?? photoMedia?.imageData {
            return UIImage(data: data)
        }
        return nil
    }

    private var headlineText: String {
        let trimmedBody = record.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBody.isEmpty {
            return trimmedBody
        }

        if let audio = firstAudioMedia {
            let transcript = trimmed(audio.caption)
            if !transcript.isEmpty {
            return transcript
            }
        }

        if let todoPayload = decodedTodoItems {
            if !todoPayload.title.isEmpty {
                return todoPayload.title
            }
            if let firstItem = todoPayload.items.first?.text, !firstItem.isEmpty {
                return firstItem
            }
        }

        if let music = firstMusicMedia {
            let title = trimmed(music.title)
            if !title.isEmpty {
                return title
            }
        }

        if let mood = MoodType(rawValue: record.mood ?? "") {
            return mood.label
        }

        if let weather = (record.weather).flatMap(WeatherCondition.init(rawValue:)) {
            let tempPrefix = record.temperature.map { "\(Int($0))° " } ?? ""
            return "\(tempPrefix)\(weather.label)"
        }

        let location = trimmed(record.location)
        if !location.isEmpty {
            return location
        }

        if let person = record.mentionedPeople?.first {
            return person.displayName
        }

        let photoCount = photoMediaCount
        if photoCount > 0 {
            return localization.string("timeline.photo.count", default: "%d photos", arguments: [photoCount])
        }

        return localization.string("detail.navigation.record", default: "Entry")
    }

    private var supportingText: String? {
        if let todoPayload = decodedTodoItems {
            let remaining = todoPayload.items.filter { !$0.isDone }.count
            return localization.string(
                "timeline.todo.summary",
                default: "%d items · %d remaining",
                arguments: [todoPayload.items.count, remaining]
            )
        }

        if let music = firstMusicMedia {
            let artist = trimmed(music.caption)
            let album = trimmed(music.albumName)
            let components = [artist, album].filter { !$0.isEmpty }
            if !components.isEmpty {
                return components.joined(separator: " · ")
            }
        }

        if let audio = firstAudioMedia {
            let duration = audioDurationString(from: audio.audioData)
            if !duration.isEmpty {
                return localization.string("timeline.audio.summary", default: "Voice note · %@", arguments: [duration])
            }
        }

        return nil
    }

    private var metaLine: String {
        var components: [String] = []
        components.append(contentsOf: recordCategoryLabels.prefix(3))

        let location = trimmed(record.location)
        if !location.isEmpty {
            components.append(location)
        }

        return Array(components.prefix(3)).joined(separator: " · ")
    }

    private var recordCategoryLabels: [String] {
        var labels: [String] = []
        let media = record.mediaCards ?? []

        if !record.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            labels.append(localization.string("timeline.category.note", default: "Note"))
        }
        if media.contains(where: { $0.mediaKind == .photo }) {
            labels.append(localization.string("timeline.category.photo", default: "Photo"))
        }
        if media.contains(where: { $0.mediaKind == .music }) {
            labels.append(localization.string("timeline.category.music", default: "Music"))
        }
        if media.contains(where: { $0.mediaKind == .audio }) {
            labels.append(localization.string("timeline.category.audio", default: "Voice"))
        }
        if media.contains(where: { $0.mediaKind == .todo }) {
            labels.append(localization.string("timeline.category.todo", default: "To-Do"))
        }
        if media.contains(where: { $0.mediaKind == .link }) {
            labels.append(localization.string("timeline.category.link", default: "Link"))
        }
        if record.weather != nil {
            labels.append(localization.string("timeline.category.weather", default: "Weather"))
        }
        if record.mood != nil {
            labels.append(localization.string("timeline.category.emotion", default: "Emotion"))
        }
        if record.latitude != nil {
            labels.append(localization.string("timeline.category.location", default: "Location"))
        }
        if !(record.mentionedPeople ?? []).isEmpty {
            labels.append(localization.string("timeline.category.people", default: "People"))
        }

        return labels
    }

    private var timeLabel: String {
        localization.templateDateString(from: record.createdAt, template: "HH:mm")
    }

    private var photoMediaCount: Int {
        (record.mediaCards ?? []).filter { $0.mediaKind == .photo }.count
    }

    private var firstMusicMedia: MediaCard? {
        (record.mediaCards ?? []).first(where: { $0.mediaKind == .music })
    }

    private var firstAudioMedia: MediaCard? {
        (record.mediaCards ?? []).first(where: { $0.mediaKind == .audio })
    }

    private var decodedTodoItems: (title: String, items: [TodoItem])? {
        guard let media = (record.mediaCards ?? []).first(where: { $0.mediaKind == .todo }),
              let json = media.caption,
              let raw = json.data(using: .utf8),
              let items = try? JSONDecoder().decode([TodoItem].self, from: raw),
              !items.isEmpty else {
            return nil
        }

        return (media.title ?? "", items)
    }

    private func trimmed(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
