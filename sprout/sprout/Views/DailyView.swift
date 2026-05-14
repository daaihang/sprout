import SwiftUI
import SwiftData

// MARK: - DailyView

/// Displays the card grid for a single calendar day.
/// Owns a @Query filtered to [startOfDay, endOfDay) so the grid automatically
/// updates when records are added, deleted, or when composition-backed projections change.
struct DailyView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.modelContext) private var modelContext
    @Environment(SproutMemoryRepository.self) private var memoryRepository
    let date: Date
    let topContentInset: CGFloat

    @Query private var records: [Record]
    @Query private var compositionStates: [CompositionItemState]
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
        let boardKey = CompositionStateRepository.boardKey(for: start)
        _compositionStates = Query(
            filter: #Predicate<CompositionItemState> { state in
                state.boardKey == boardKey
            },
            sort: \CompositionItemState.updatedAt,
            order: .reverse
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

            if !recentReflections.isEmpty {
                recentReflectionsSection
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
        _ = compositionStates.count
        return homeBoardBuilder.buildGridItems(
            for: date,
            records: records,
            systemConfigs: systemConfigs
        )
    }

    private var recentReflections: [ReflectionSnapshot] {
        memoryRepository.savedReflectionsForHome(referenceDate: date, limit: 5)
    }

    private var recentReflectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("content.recent_reflections", "Recent Reflections"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            VStack(spacing: 10) {
                ForEach(recentReflections, id: \.id) { reflection in
                    NavigationLink {
                        ReflectionDetailView(reflection: reflection)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text("💭")
                                    .font(.subheadline)
                                Text(reflection.title)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(2)
                                    .foregroundStyle(.primary)
                            }

                            if !reflection.body.isEmpty {
                                Text(reflection.body.prefix(100))
                                    .font(.caption)
                                    .lineLimit(2)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 8) {
                                if let arcID = reflection.linkedTemporalArcID,
                                   let arc = memoryRepository.temporalArc(for: arcID) {
                                    Text("Phase: \(arc.title)")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.orange.opacity(0.12), in: Capsule())
                                }
                                Spacer()
                                Text(reflection.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .background(Color.secondary.opacity(0.04))
    }

// MARK: - CardWrapper

/// Wraps a projected home board card with target-aware navigation.
struct HomeBoardCardWrapper: View {
    @Environment(SproutMemoryRepository.self) private var memoryRepository
    let projection: CompositionProjectionCard

    var body: some View {
        NavigationLink {
            destinationView
        } label: {
            projection.cardView
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var destinationView: some View {
        switch projection.targetType {
        case .artifact:
            if let artifact = artifactTarget {
                ArtifactDetailView(artifact: artifact)
            } else {
                fallbackRecordDetailView
            }
        case .record:
            fallbackRecordDetailView
        case .arc:
            if let arc = memoryRepository.temporalArc(for: projection.targetID) {
                TemporalArcDetailView(arc: arc)
            } else {
                fallbackRecordDetailView
            }
        case .reflection:
            if let reflection = reflectionTarget {
                ReflectionDetailView(reflection: reflection)
            } else {
                fallbackRecordDetailView
            }
        case .system:
            fallbackRecordDetailView
        }
    }

    private var artifactTarget: Artifact? {
        memoryRepository.artifacts.first { $0.id == projection.targetID }
    }

    private var reflectionTarget: ReflectionSnapshot? {
        memoryRepository.reflections.first { $0.id == projection.targetID }
    }

    private var fallbackRecordDetailView: some View {
        RecordDetailView(
            record: projection.record,
            focusedSection: projection.focusedSection
        )
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

