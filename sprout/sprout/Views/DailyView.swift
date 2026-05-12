import SwiftUI
import SwiftData

// MARK: - DailyView

/// Displays the card grid for a single calendar day.
/// Owns a @Query filtered to [startOfDay, endOfDay) so the grid automatically
/// updates when records are added, deleted, or modified (e.g. cardUnits change).
struct DailyView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.modelContext) private var modelContext
    let date: Date
    let topContentInset: CGFloat

    @Query private var records: [Record]
    @Query(sort: \DashboardSystemCardConfig.dashboardOrder, order: .forward) private var systemConfigs: [DashboardSystemCardConfig]

    init(date: Date, topContentInset: CGFloat = 0) {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!
        _records = Query(
            filter: #Predicate<Record> { r in
                r.createdAt >= start && r.createdAt < end
            },
            sort: \Record.createdAt, order: .reverse
        )
        self.date = date
        self.topContentInset = topContentInset
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            HomePullToOpenProbe()

            if gridItems.isEmpty {
                EmptyDayView(date: date)
                    .frame(minHeight: 520)
            } else {
                CardGridView(
                    items: gridItems
                )
            }
        }
        .background {
            HomeBackgroundView()
                .ignoresSafeArea()
        }
        .contentMargins(.top, topContentInset, for: .scrollContent)
        .contentMargins(.bottom, 104, for: .scrollContent)
        .ignoresSafeArea(.container, edges: .bottom)
        .task {
            ensureTodayInHistoryConfig()
        }
    }

    private var gridItems: [GridItem] {
        let recordItems: [(order: Double, item: GridItem)] = orderedRecords.enumerated().flatMap { index, record in
            let baseOrder = normalizedOrder(for: record) + Double(index) * 0.001
            return RecordMapper.allCards(record: record).enumerated().map { cardIndex, info in
                let spans = availableSpans(for: info.cardType)
                return (
                    order: baseOrder + Double(cardIndex) * 0.0001,
                    item: GridItem(
                        id: info.id,
                        recordID: info.record.id,
                        card: AnyView(CardWrapper(info: info)),
                        columns: info.columns,
                        units: info.units,
                        availableSpans: spans,
                        onResize: { span in
                            resizeCard(info, to: span)
                        },
                        onDelete: {
                            modelContext.delete(info.record)
                        }
                    )
                )
            }
        }

        let systemItems = systemGridEntries
        return (systemItems + recordItems).sorted { $0.order < $1.order }.map(\.item)
    }

    private var systemGridEntries: [(order: Double, item: GridItem)] {
        guard let config = todayInHistoryConfig,
              let memoryData = todayInHistoryData
        else { return [] }

        let span = sizeLimits(for: DashboardSystemCardConfig.todayInHistoryKind).clamped(span: config.span)
        return [
            (
                order: config.dashboardOrder,
                item: GridItem(
                    id: "system-\(DashboardSystemCardConfig.todayInHistoryKind)",
                    recordID: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
                    card: AnyView(
                        NavigationLink(
                            destination: TodayInHistoryDetailView(selectedDate: date, entries: memoryData.entries)
                        ) {
                            TodayInHistoryCard(data: memoryData)
                        }
                        .buttonStyle(.plain)
                    ),
                    columns: span.widthColumns,
                    units: span.heightUnits,
                    availableSpans: availableSpans(for: DashboardSystemCardConfig.todayInHistoryKind),
                    onResize: { newSpan in
                        config.setSpan(newSpan)
                    },
                    onDelete: {
                        config.isEnabled = false
                    }
                )
            )
        ]
    }

    private var orderedRecords: [Record] {
        records.sorted {
            normalizedOrder(for: $0) < normalizedOrder(for: $1)
        }
    }

    private func normalizedOrder(for record: Record) -> Double {
        record.dashboardOrder == 0 ? record.createdAt.timeIntervalSince1970 : record.dashboardOrder
    }

    private func resizeCard(_ info: DashboardCardInfo, to span: ContainerSpan) {
        let siblingCards = RecordMapper.allCards(record: info.record)
        for sibling in siblingCards where !info.record.hasDashboardContainerSpanOverride(for: sibling.spanKey) {
            let currentSpan = ContainerSpan(widthColumns: sibling.columns, heightUnits: sibling.units)
            info.record.setDashboardContainerSpan(currentSpan, for: sibling.spanKey)
        }

        info.record.setDashboardContainerSpan(span, for: info.spanKey)
    }

    private var todayInHistoryConfig: DashboardSystemCardConfig? {
        if let existing = systemConfigs.first(where: { $0.kind == DashboardSystemCardConfig.todayInHistoryKind }) {
            if existing.isEnabled { return existing }
            return nil
        }

        return nil
    }

    private var todayInHistoryData: TodayInHistoryCardData? {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: date)
        let matching = allRecordsForSameMonthDay()
            .filter { calendar.component(.year, from: $0.createdAt) < currentYear }
            .sorted { $0.createdAt > $1.createdAt }

        guard !matching.isEmpty else { return nil }

        let monthDay = localization.templateDateString(from: date, template: "MMMM d")
        return TodayInHistoryCardData(
            monthDayLabel: monthDay,
            entries: matching.map { TodayInHistoryEntry(record: $0, referenceYear: currentYear) }
        )
    }

    private func allRecordsForSameMonthDay() -> [Record] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date

        var descriptor = FetchDescriptor<Record>(
            predicate: #Predicate<Record> { record in
                record.createdAt < end
            },
            sortBy: [SortDescriptor(\Record.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 2048
        let candidates = (try? modelContext.fetch(descriptor)) ?? []
        return candidates.filter {
            calendar.component(.month, from: $0.createdAt) == month
                && calendar.component(.day, from: $0.createdAt) == day
                && calendar.component(.year, from: $0.createdAt) < currentYear
        }
    }

    private func ensureTodayInHistoryConfig() {
        guard systemConfigs.first(where: { $0.kind == DashboardSystemCardConfig.todayInHistoryKind }) == nil else {
            return
        }
        let created = DashboardSystemCardConfig(
            kind: DashboardSystemCardConfig.todayInHistoryKind,
            isEnabled: true,
            widthColumns: 4,
            heightUnits: 4,
            dashboardOrder: -10_000
        )
        modelContext.insert(created)
    }
}

// MARK: - CardWrapper

/// Wraps a single DashboardCardInfo with NavigationLink.
struct CardWrapper: View {
    let info: DashboardCardInfo

    var body: some View {
        NavigationLink(
            destination: RecordDetailView(
                record: info.record,
                focusedSection: info.focusedSection
            )
        ) {
            info.cardView
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EmptyDayView

struct EmptyDayView: View {
    @Environment(AppLocalization.self) private var localization
    let date: Date

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))

            VStack(spacing: 6) {
                Text(dateLabel)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(t("content.empty.title", "No entries yet"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(t("content.empty.subtitle", "Use the input bar below to add your first entry today"))
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    private var dateLabel: String {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        if cal.isDate(date, inSameDayAs: today) {
            return t("content.date.today", "Today")
        }
        return localization.templateDateString(from: date, template: "MMM d EEEE")
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}
