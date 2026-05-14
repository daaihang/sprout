import SwiftUI
import SwiftData

// MARK: - DailyView

struct DailyView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(SproutMemoryRepository.self) private var memoryRepository
    let date: Date
    let topContentInset: CGFloat

    @Query private var compositionStates: [CompositionItem]

    private var compositionStateRepository: CompositionStateRepository {
        CompositionStateRepository(modelContext: memoryRepository.modelContext)
    }

    private var homeBoardBuilder: HomeBoardCompositionBuilder {
        HomeBoardCompositionBuilder(
            dependencies: .init(
                modelContext: memoryRepository.modelContext,
                memoryRepository: memoryRepository,
                stateRepository: compositionStateRepository,
                cardProjector: CompositionProjector(),
                prominenceEngine: HomeBoardProminenceEngine()
            )
        )
    }

    init(date: Date, topContentInset: CGFloat = 0) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let boardKey = CompositionStateRepository.boardKey(for: start)
        _compositionStates = Query(
            filter: #Predicate<CompositionItem> { state in
                state.boardKey == boardKey
            },
            sort: \CompositionItem.updatedAt,
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
                CardGridView(items: gridItems)
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
            homeBoardBuilder.ensureCompositionContext(for: date)
        }
    }

    private var dayRecordShells: [RecordShell] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return memoryRepository.recordShells
            .filter { $0.createdAt >= start && $0.createdAt < end }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var gridItems: [GridItem] {
        _ = compositionStates.count
        return homeBoardBuilder.buildGridItems(
            for: date,
            recordShells: dayRecordShells
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

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}

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
                missingTargetView
            }
        case .record:
            recordDetailView
        case .arc:
            if let arc = memoryRepository.temporalArc(for: projection.targetID) {
                TemporalArcDetailView(arc: arc)
            } else {
                missingTargetView
            }
        case .reflection:
            if let reflection = reflectionTarget {
                ReflectionDetailView(reflection: reflection)
            } else {
                missingTargetView
            }
        case .system:
            recordDetailView
        }
    }

    private var artifactTarget: Artifact? {
        memoryRepository.artifacts.first { $0.id == projection.targetID }
    }

    private var reflectionTarget: ReflectionSnapshot? {
        memoryRepository.reflections.first { $0.id == projection.targetID }
    }

    private var recordDetailView: some View {
        MemoryRecordDetailView(
            recordID: projection.recordID,
            focusedSection: projection.focusedSection
        )
    }

    private var missingTargetView: some View {
        ContentUnavailableView(
            "Content Unavailable",
            systemImage: "exclamationmark.triangle",
            description: Text("The selected memory target is missing from the new architecture store.")
        )
    }
}

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
                Text(localization.string("content.empty_day.subtitle", default: "No memories were captured for this day yet."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var dateLabel: String {
        localization.templateDateString(from: date, template: "MMMM d")
    }
}
