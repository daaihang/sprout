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
        return record.cardType.capitalized
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
        Group {
            if let data, !data.isEmpty {
                GeometryReader { geo in
                    contentView(data, metrics: CardLayoutMetrics(containerSize: geo.size))
                }
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
    }

    private func contentView(_ data: TodayInHistoryCardData, metrics: CardLayoutMetrics) -> some View {
        let maxItems = metrics.isTallHeight ? 4 : (metrics.isWideWidth ? 3 : 2)

        return VStack(alignment: .leading, spacing: metrics.isCompactHeight ? 8 : 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Label(
                        localizedString("card.memory.title", default: "On This Day"),
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                    Text(data.monthDayLabel)
                        .font(.system(size: metrics.isWideWidth ? 22 : 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 8)

                Text(localizedString("card.memory.count", default: "%d records", arguments: [data.totalCount]))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.08), in: Capsule())
            }

            Text(
                localizedString(
                    "card.memory.summary",
                    default: "You recorded %d entries on this day before. The earliest was %d years ago.",
                    arguments: [data.totalCount, max(data.oldestYearsAgo, 1)]
                )
            )
            .font(.system(size: metrics.isTallHeight ? 14 : 12, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(metrics.isTallHeight ? 3 : 2)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(data.entries.prefix(maxItems))) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 2) {
                            Text("\(entry.year)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                            Text(localizedString("card.memory.years_ago", default: "%dY", arguments: [max(entry.yearsAgo, 1)]))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 42)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if !entry.subtitle.isEmpty && (!metrics.isCompactHeight || metrics.isWideWidth) {
                                Text(entry.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                }
            }

            if data.totalCount > maxItems {
                Text(localizedString("card.memory.more", default: "+%d more memories", arguments: [data.totalCount - maxItems]))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(metrics.isCompactHeight ? 12 : 16)
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
