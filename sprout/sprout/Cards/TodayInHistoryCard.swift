import SwiftUI

struct TodayInHistoryEntry: Identifiable {
    let id: UUID
    let record: Record
    let date: Date
    let title: String
    let subtitle: String
    let year: Int
    let yearsAgo: Int

    init(record: Record, referenceYear: Int) {
        self.id = record.id
        self.record = record
        self.date = record.createdAt
        self.year = Calendar.current.component(.year, from: record.createdAt)
        self.yearsAgo = max(referenceYear - self.year, 0)
        self.title = TodayInHistoryEntry.makeTitle(for: record)
        self.subtitle = TodayInHistoryEntry.makeSubtitle(for: record)
    }

    private static func makeTitle(for record: Record) -> String {
        let body = record.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty { return String(body.prefix(36)) }
        if let location = record.location, !location.isEmpty { return location }
        if let music = (record.mediaCards ?? []).first(where: { $0.type == "music" })?.title, !music.isEmpty {
            return music
        }
        if (record.mediaCards ?? []).contains(where: { $0.type == "photo" }) {
            return localizedString("card.memory.photo_title", default: "Photo Memory")
        }
        return localizedString("card.memory.default_title", default: "Past Entry")
    }

    private static func makeSubtitle(for record: Record) -> String {
        if let weather = record.weather, !weather.isEmpty {
            return weather
        }
        if let mood = record.mood, let moodType = MoodType(rawValue: mood) {
            return moodType.label
        }
        if let person = record.mentionedPeople?.first, !person.name.isEmpty {
            return person.nickname ?? person.name
        }
        return record.cardKind.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
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
