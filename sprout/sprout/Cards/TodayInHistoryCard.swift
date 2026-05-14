import SwiftUI

struct TodayInHistoryEntry: Identifiable {
    let id: UUID
    let record: Record
    let date: Date
    let title: String
    let subtitle: String
    let year: Int
    let yearsAgo: Int

    init(record: Record, projection: RecordEvidenceProjector.Projection, referenceYear: Int) {
        self.id = record.id
        self.record = record
        self.date = record.createdAt
        self.year = Calendar.current.component(.year, from: record.createdAt)
        self.yearsAgo = max(referenceYear - self.year, 0)
        self.title = TodayInHistoryEntry.makeTitle(from: projection)
        self.subtitle = TodayInHistoryEntry.makeSubtitle(from: projection)
    }

    init(record: Record, referenceYear: Int) {
        self.init(
            record: record,
            projection: RecordEvidenceProjector(localization: AppLocalization.shared)
                .project(record: record, memoryView: nil),
            referenceYear: referenceYear
        )
    }

    private static func makeTitle(from projection: RecordEvidenceProjector.Projection) -> String {
        let headline = projection.headlineText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !headline.isEmpty {
            return String(headline.prefix(36))
        }
        if let location = projection.linkedLocationName, !location.isEmpty {
            return location
        }
        if projection.primaryKind == .photo {
            return localizedString("card.memory.photo_title", default: "Photo Memory")
        }
        return localizedString("card.memory.default_title", default: "Past Entry")
    }

    private static func makeSubtitle(from projection: RecordEvidenceProjector.Projection) -> String {
        if let weather = projection.weatherCondition {
            return weather.label
        }
        if let mood = projection.mood {
            return mood.label
        }
        if let person = projection.primaryPersonName, !person.isEmpty {
            return person
        }
        switch projection.primaryKind {
        case .photo:
            return localizedString("timeline.category.photo", default: "Photo")
        case .music:
            return localizedString("timeline.category.music", default: "Music")
        case .audio:
            return localizedString("timeline.category.audio", default: "Voice")
        case .todo:
            return localizedString("timeline.category.todo", default: "To-Do")
        case .link:
            return localizedString("timeline.category.link", default: "Link")
        case .map:
            return localizedString("timeline.category.location", default: "Location")
        case .activity:
            return localizedString("timeline.category.activity", default: "Activity")
        case .emotion:
            return localizedString("timeline.category.emotion", default: "Emotion")
        case .weather:
            return localizedString("timeline.category.weather", default: "Weather")
        case .people:
            return localizedString("timeline.category.people", default: "People")
        case .text, .quote, .todayInHistory, .book, .film, .game, .ticket, .health:
            return localizedString("timeline.category.note", default: "Note")
        }
    }
}

struct TodayInHistoryCardData {
    var monthDayLabel: String
    var entries: [TodayInHistoryEntry]

    var totalCount: Int { entries.count }
    var oldestYearsAgo: Int { entries.map(\.yearsAgo).max() ?? 0 }
    var isEmpty: Bool { entries.isEmpty }
}

struct TodayInHistoryCard: View {
    var data: TodayInHistoryCardData?

    var body: some View {
        AdaptiveCardRoot(content: memoryContent) {
            placeholderView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
    }

    private var memoryContent: AdaptiveCardContent? {
        guard let data, !data.isEmpty else { return nil }

        let visibleEntries = Array(data.entries.prefix(4))
        return AdaptiveCardContent(
            preferredLayout: .stackedInfo,
            accent: .accentColor,
            visual: .symbol("clock.arrow.circlepath", tint: .accentColor, renderingMode: .hierarchical),
            title: localizedString("card.memory.title", default: "On This Day"),
            subtitle: data.monthDayLabel,
            body: localizedString(
                "card.memory.summary",
                default: "You recorded %d entries on this day before. The earliest was %d years ago.",
                arguments: [data.totalCount, max(data.oldestYearsAgo, 1)]
            ),
            badge: AdaptiveCardBadge(
                text: localizedString("card.memory.count", default: "%d records", arguments: [data.totalCount]),
                systemImage: "calendar"
            ),
            listItems: visibleEntries.map { entry in
                AdaptiveCardListItem(
                    systemImage: "clock",
                    symbolColor: .accentColor,
                    title: "\(entry.year) · \(entry.title)",
                    subtitle: entry.subtitle.isEmpty ? localizedString("card.memory.years_ago", default: "%dY", arguments: [max(entry.yearsAgo, 1)]) : "\(localizedString("card.memory.years_ago", default: "%dY", arguments: [max(entry.yearsAgo, 1)])) · \(entry.subtitle)",
                    emphasis: true
                )
            },
            footer: data.totalCount > visibleEntries.count
                ? localizedString("card.memory.more", default: "+%d more memories", arguments: [data.totalCount - visibleEntries.count])
                : nil
        )
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.4))
            Text(localizedString("card.memory.placeholder", default: "No memories from this day yet"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TodayInHistoryDetailView: View {
    @Environment(AppLocalization.self) private var localization
    let selectedDate: Date
    let entries: [TodayInHistoryEntry]

    private var groupedEntries: [(year: Int, items: [TodayInHistoryEntry])] {
        Dictionary(grouping: entries, by: \.year)
            .map { (year: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.year > $1.year }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localizedString("card.memory.title", default: "On This Day"))
                        .font(.title2.weight(.semibold))
                    Text(
                        localization.templateDateString(
                            from: selectedDate,
                            template: "MMMM d"
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                ForEach(groupedEntries, id: \.year) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(group.year)")
                            .font(.headline)

                        ForEach(group.items) { entry in
                            NavigationLink(
                                destination: RecordDetailView(record: entry.record)
                            ) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    if !entry.subtitle.isEmpty {
                                        Text(entry.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary.opacity(0.75))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle(localizedString("card.memory.detail_title", default: "Past Memories"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
