import SwiftUI
import SwiftData
import UIKit

struct RecordTimelineView: View {
    @Environment(AppLocalization.self) private var localization
    @Query(sort: \Record.createdAt, order: .reverse) private var records: [Record]

    let selectedDate: Date

    @State private var hasPerformedInitialScroll = false

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
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                if daySections.isEmpty {
                    emptyState
                        .padding(.top, 88)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 120)
                } else {
                    LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                        ForEach(daySections) { section in
                            Section {
                                VStack(spacing: 10) {
                                    ForEach(section.records) { record in
                                        RecordTimelineRow(record: record)
                                    }
                                }
                                .id(section.id)
                            } header: {
                                sectionHeader(for: section.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 104)
                }
            }
            .task(id: sectionIDs) {
                guard !hasPerformedInitialScroll, !daySections.isEmpty else { return }
                hasPerformedInitialScroll = true
                await scroll(to: selectedDate, using: proxy, animated: false)
            }
            .onChange(of: selectedDate) { _, newValue in
                Task {
                    await scroll(to: newValue, using: proxy, animated: true)
                }
            }
        }
    }

    private func scroll(to date: Date, using proxy: ScrollViewProxy, animated: Bool) async {
        guard let target = targetSectionDate(for: date) else { return }

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

    private func targetSectionDate(for requestedDate: Date) -> Date? {
        guard !daySections.isEmpty else { return nil }

        let targetDay = Calendar.current.startOfDay(for: requestedDate)
        if daySections.contains(where: { Calendar.current.isDate($0.id, inSameDayAs: targetDay) }) {
            return targetDay
        }

        return daySections.min {
            abs($0.id.timeIntervalSince(targetDay)) < abs($1.id.timeIntervalSince(targetDay))
        }?.id
    }

    private func sectionHeader(for date: Date) -> some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .frame(maxWidth: .infinity)

            HStack {
                Text(sectionTitle(for: date))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                Spacer()
            }
            .padding(.vertical, 4)
        }
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

private struct RecordDaySection: Identifiable {
    let id: Date
    let records: [Record]
}

private struct RecordTimelineRow: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.colorScheme) private var colorScheme

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
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04), lineWidth: 0.5)
            )
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.05),
                radius: 10, x: 0, y: 4
            )
        }
        .buttonStyle(.plain)
    }

    private var preferredFocusedSection: RecordSection {
        if !record.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text
        }
        return RecordMapper.allCards(record: record).first?.focusedSection ?? .text
    }

    @ViewBuilder
    private var preview: some View {
        if record.cardType == "photo", let image = photoPreviewImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else if record.cardType == "emotion", let mood = MoodType(rawValue: record.mood ?? "") {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(mood.color.opacity(0.16))
                .frame(width: 62, height: 62)
                .overlay(
                    Text(mood.emoji)
                        .font(.system(size: 30))
                )
        } else if record.cardType == "people", let person = record.mentionedPeople?.first {
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
        switch record.cardType {
        case "music":   return "music.note"
        case "weather": return (record.weather).flatMap(WeatherCondition.init(rawValue:))?.sfSymbol ?? "cloud.sun.fill"
        case "todo":    return "checklist"
        case "map":     return "mappin.and.ellipse"
        case "audio":   return "waveform"
        case "people":  return "person.2.fill"
        case "photo":   return "photo"
        case "emotion": return "face.smiling"
        case "link":    return "link"
        default:        return "text.alignleft"
        }
    }

    private var previewTint: Color {
        switch record.cardType {
        case "weather":
            return (record.weather).flatMap(WeatherCondition.init(rawValue:))?.color ?? .accentColor
        case "audio":
            return .orange
        case "music":
            return .pink
        case "map":
            return .green
        case "todo":
            return .accentColor
        case "link":
            return .blue
        default:
            return .accentColor
        }
    }

    private var photoPreviewImage: UIImage? {
        let photoMedia = (record.mediaCards ?? []).first(where: { $0.type == "photo" })
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
        if media.contains(where: { $0.type == "photo" }) {
            labels.append(localization.string("timeline.category.photo", default: "Photo"))
        }
        if media.contains(where: { $0.type == "music" }) {
            labels.append(localization.string("timeline.category.music", default: "Music"))
        }
        if media.contains(where: { $0.type == "audio" }) {
            labels.append(localization.string("timeline.category.audio", default: "Voice"))
        }
        if media.contains(where: { $0.type == "todo" }) {
            labels.append(localization.string("timeline.category.todo", default: "To-Do"))
        }
        if media.contains(where: { $0.type == "link" }) {
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
        (record.mediaCards ?? []).filter { $0.type == "photo" }.count
    }

    private var firstMusicMedia: MediaCard? {
        (record.mediaCards ?? []).first(where: { $0.type == "music" })
    }

    private var firstAudioMedia: MediaCard? {
        (record.mediaCards ?? []).first(where: { $0.type == "audio" })
    }

    private var decodedTodoItems: (title: String, items: [TodoItem])? {
        guard let media = (record.mediaCards ?? []).first(where: { $0.type == "todo" }),
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
