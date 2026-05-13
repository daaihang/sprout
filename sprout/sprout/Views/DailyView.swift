import SwiftUI
import SwiftData

// MARK: - DailyView

/// Displays the card grid for a single calendar day.
/// Owns a @Query filtered to [startOfDay, endOfDay) so the grid automatically
/// updates when records are added, deleted, or modified (e.g. cardUnits change).
struct DailyView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.modelContext) private var modelContext
    @Environment(SproutMemoryRepository.self) private var memoryRepository
    let date: Date
    let topContentInset: CGFloat

    @Query private var records: [Record]
    @Query(sort: \DashboardSystemCardConfig.dashboardOrder, order: .forward) private var systemConfigs: [DashboardSystemCardConfig]
    private var compositionStateRepository: CompositionStateRepository {
        CompositionStateRepository(modelContext: modelContext)
    }
    private var homeBoardBuilder: HomeBoardCompositionBuilder {
        HomeBoardCompositionBuilder(
            dependencies: .init(
                modelContext: modelContext,
                memoryRepository: memoryRepository,
                stateRepository: compositionStateRepository,
                cardProjector: CompositionProjector(),
                prominenceEngine: HomeBoardProminenceEngine()
            )
        )
    }

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
        .background(Color.clear)
        .contentMargins(.top, topContentInset, for: .scrollContent)
        .contentMargins(.bottom, 104, for: .scrollContent)
        .ignoresSafeArea(.container, edges: .bottom)
        .task {
            homeBoardBuilder.ensureTodayInHistoryConfig(systemConfigs: systemConfigs)
            homeBoardBuilder.ensureCompositionContext(for: date)
        }
    }

    private var gridItems: [GridItem] {
        homeBoardBuilder.buildGridItems(
            for: date,
            records: records,
            systemConfigs: systemConfigs
        )
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
