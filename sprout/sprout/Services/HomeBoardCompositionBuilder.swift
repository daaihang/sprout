import SwiftUI
import SwiftData

@MainActor
struct HomeBoardCompositionBuilder {
    struct Dependencies {
        let modelContext: ModelContext
        let memoryRepository: SproutMemoryRepository
        let stateRepository: CompositionStateRepository
        let cardProjector: CompositionProjector
        let prominenceEngine: HomeBoardProminenceEngine
    }

    let dependencies: Dependencies

    func buildGridItems(for date: Date, records: [Record], systemConfigs: [DashboardSystemCardConfig]) -> [GridItem] {
        let compositionContext = dependencies.stateRepository.compositionContext(for: date)
        let compositionKey = compositionContext.compositionKey

        let recordItems = buildRecordEntries(
            records: records,
            compositionKey: compositionKey
        )
        let systemItems = buildTodayInHistoryEntries(
            date: date,
            systemConfigs: systemConfigs,
            compositionContext: compositionContext
        )
        let arcItems = buildTemporalArcEntries(
            date: date,
            compositionContext: compositionContext
        )
        let reflectionItems = buildPhaseReflectionEntries(
            date: date,
            compositionContext: compositionContext
        )
        let savedReflectionItems = buildSavedReflectionEntries(
            date: date,
            compositionContext: compositionContext
        )

        return (systemItems + arcItems + reflectionItems + savedReflectionItems + recordItems)
            .sorted { $0.order < $1.order }
            .map(\.item)
    }

    func ensureCompositionContext(for date: Date) {
        _ = dependencies.stateRepository.compositionContext(for: date)
    }

    func resizeProjection(_ projection: CompositionProjectionCard, to span: ContainerSpan, on date: Date) {
        let compositionContext = dependencies.stateRepository.compositionContext(for: date)
        dependencies.stateRepository.upsertState(
            boardID: compositionContext.board.id,
            boardKey: compositionContext.boardKey,
            compositionID: compositionContext.composition.id,
            compositionKey: compositionContext.compositionKey,
            itemKey: projection.compositionItemKey,
            targetType: projection.targetType.rawValue,
            targetID: projection.targetID,
            span: span,
            zIndex: projection.zIndex,
            rotationDegrees: projection.rotationDegrees,
            scale: projection.scale
        )
    }

    func resizeTodayInHistoryCard(to span: ContainerSpan, on date: Date) {
        let compositionContext = dependencies.stateRepository.compositionContext(for: date)
        let itemID = "system-\(DashboardSystemCardConfig.todayInHistoryKind)"
        let prominence = dependencies.prominenceEngine.prominence(for: .systemTodayInHistory)
        let fallbackState = dependencies.stateRepository.resolvedState(
            compositionKey: compositionContext.compositionKey,
            itemKey: itemID,
            fallbackSpan: prominence.fallbackSpan,
            fallbackZIndex: prominence.fallbackZIndex,
            fallbackRotationDegrees: stickerRotation(for: itemID),
            fallbackScale: stickerScale(for: itemID)
        )
        dependencies.stateRepository.upsertState(
            boardID: compositionContext.board.id,
            boardKey: compositionContext.boardKey,
            compositionID: compositionContext.composition.id,
            compositionKey: compositionContext.compositionKey,
            itemKey: itemID,
            targetType: CompositionProjectionTargetType.system.rawValue,
            targetID: todayInHistoryTargetID,
            span: span,
            zIndex: fallbackState.zIndex,
            rotationDegrees: fallbackState.rotationDegrees,
            scale: fallbackState.scale
        )
    }

    func resizeTemporalArcCard(_ arc: TemporalArc, to span: ContainerSpan, on date: Date) {
        let compositionContext = dependencies.stateRepository.compositionContext(for: date)
        let itemID = "arc-\(arc.id.uuidString)"
        let prominence = dependencies.prominenceEngine.prominence(for: .temporalArc, arc: arc)
        let fallbackState = dependencies.stateRepository.resolvedState(
            compositionKey: compositionContext.compositionKey,
            itemKey: itemID,
            fallbackSpan: prominence.fallbackSpan,
            fallbackZIndex: prominence.fallbackZIndex,
            fallbackRotationDegrees: stickerRotation(for: itemID),
            fallbackScale: stickerScale(for: itemID)
        )
        dependencies.stateRepository.upsertState(
            boardID: compositionContext.board.id,
            boardKey: compositionContext.boardKey,
            compositionID: compositionContext.composition.id,
            compositionKey: compositionContext.compositionKey,
            itemKey: itemID,
            targetType: CompositionProjectionTargetType.arc.rawValue,
            targetID: arc.id,
            span: span,
            zIndex: fallbackState.zIndex,
            rotationDegrees: fallbackState.rotationDegrees,
            scale: fallbackState.scale
        )
    }

    func resizePhaseReflectionCard(_ reflection: ReflectionSnapshot, to span: ContainerSpan, on date: Date) {
        resizeReflectionCard(reflection, to: span, on: date)
    }

    func resizeReflectionCard(_ reflection: ReflectionSnapshot, to span: ContainerSpan, on date: Date) {
        let compositionContext = dependencies.stateRepository.compositionContext(for: date)
        let itemID = "reflection-\(reflection.id.uuidString)"
        let prominence = dependencies.prominenceEngine.prominence(for: .phaseReflection, reflection: reflection)
        let fallbackState = dependencies.stateRepository.resolvedState(
            compositionKey: compositionContext.compositionKey,
            itemKey: itemID,
            fallbackSpan: prominence.fallbackSpan,
            fallbackZIndex: prominence.fallbackZIndex,
            fallbackRotationDegrees: stickerRotation(for: itemID),
            fallbackScale: stickerScale(for: itemID)
        )
        dependencies.stateRepository.upsertState(
            boardID: compositionContext.board.id,
            boardKey: compositionContext.boardKey,
            compositionID: compositionContext.composition.id,
            compositionKey: compositionContext.compositionKey,
            itemKey: itemID,
            targetType: CompositionProjectionTargetType.reflection.rawValue,
            targetID: reflection.id,
            span: span,
            zIndex: fallbackState.zIndex,
            rotationDegrees: fallbackState.rotationDegrees,
            scale: fallbackState.scale
        )
    }

    func todayInHistoryConfig(from systemConfigs: [DashboardSystemCardConfig]) -> DashboardSystemCardConfig? {
        guard let existing = systemConfigs.first(where: { $0.kind == DashboardSystemCardConfig.todayInHistoryKind }) else {
            return nil
        }
        return existing.isEnabled ? existing : nil
    }

    func todayInHistoryData(for date: Date) -> TodayInHistoryCardData? {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: date)
        let matching = allRecordsForSameMonthDay(date: date)
            .filter { calendar.component(.year, from: $0.createdAt) < currentYear }
            .sorted { $0.createdAt > $1.createdAt }

        guard !matching.isEmpty else { return nil }

        let monthDay = localizedDate(date, template: "MMMM d")
        return TodayInHistoryCardData(
            monthDayLabel: monthDay,
            entries: matching.map { TodayInHistoryEntry(record: $0, referenceYear: currentYear) }
        )
    }

    func ensureTodayInHistoryConfig(systemConfigs: [DashboardSystemCardConfig]) {
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
        dependencies.modelContext.insert(created)
    }

    private var todayInHistoryTargetID: UUID {
        UUID(uuidString: "00000000-0000-0000-0000-000000000100") ?? UUID()
    }

    private func buildRecordEntries(records: [Record], compositionKey: String) -> [(order: Double, item: GridItem)] {
        orderedRecords(records).enumerated().flatMap { index, record in
            let baseOrder = normalizedOrder(for: record) + Double(index) * 0.001
            return dependencies.cardProjector.projectCards(
                for: record,
                memoryRepository: dependencies.memoryRepository,
                stateRepository: dependencies.stateRepository,
                compositionKey: compositionKey
            ).enumerated().map { cardIndex, projection in
                let spans = availableSpans(for: projection.cardType)
                return (
                    order: baseOrder + Double(cardIndex) * 0.0001,
                    item: GridItem(
                        id: projection.id,
                        projectionTargetType: projection.targetType.rawValue,
                        projectionTargetID: projection.targetID,
                        recordID: projection.record.id,
                        card: AnyView(HomeBoardCardWrapper(projection: projection)),
                        columns: projection.columns,
                        units: projection.units,
                        zIndex: projection.zIndex,
                        rotationDegrees: projection.rotationDegrees,
                        scale: projection.scale,
                        availableSpans: spans,
                        deleteActionTitle: "Delete Memory",
                        deleteActionSystemImage: "trash",
                        onResize: { span in
                            resizeProjection(projection, to: span, on: record.createdAt)
                        },
                        onDelete: {
                            dependencies.modelContext.delete(projection.record)
                        }
                    )
                )
            }
        }
    }

    private func buildTodayInHistoryEntries(
        date: Date,
        systemConfigs: [DashboardSystemCardConfig],
        compositionContext: CompositionStateRepository.ResolvedCompositionContext
    ) -> [(order: Double, item: GridItem)] {
        guard let config = todayInHistoryConfig(from: systemConfigs),
              let memoryData = todayInHistoryData(for: date)
        else { return [] }

        let itemID = "system-\(DashboardSystemCardConfig.todayInHistoryKind)"
        let prominence = dependencies.prominenceEngine.prominence(for: .systemTodayInHistory)
        let resolvedState = dependencies.stateRepository.resolvedState(
            compositionKey: compositionContext.compositionKey,
            itemKey: itemID,
            fallbackSpan: prominence.fallbackSpan,
            fallbackZIndex: prominence.fallbackZIndex,
            fallbackRotationDegrees: stickerRotation(for: itemID),
            fallbackScale: stickerScale(for: itemID)
        )

        return [
            (
                order: prominence.order,
                item: GridItem(
                    id: itemID,
                    projectionTargetType: CompositionProjectionTargetType.system.rawValue,
                    projectionTargetID: todayInHistoryTargetID,
                    recordID: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
                    card: AnyView(
                        NavigationLink(
                            destination: TodayInHistoryDetailView(selectedDate: date, entries: memoryData.entries)
                        ) {
                            TodayInHistoryCard(data: memoryData)
                        }
                        .buttonStyle(.plain)
                    ),
                    columns: resolvedState.span.widthColumns,
                    units: resolvedState.span.heightUnits,
                    zIndex: resolvedState.zIndex,
                    rotationDegrees: resolvedState.rotationDegrees,
                    scale: resolvedState.scale,
                    availableSpans: availableSpans(for: DashboardSystemCardConfig.todayInHistoryKind),
                    deleteActionTitle: "Hide System Card",
                    deleteActionSystemImage: "eye.slash",
                    onResize: { newSpan in
                        resizeTodayInHistoryCard(to: newSpan, on: date)
                    },
                    onDelete: {
                        config.isEnabled = false
                    }
                )
            )
        ]
    }

    private func buildSavedReflectionEntries(
        date: Date,
        compositionContext: CompositionStateRepository.ResolvedCompositionContext
    ) -> [(order: Double, item: GridItem)] {
        let savedReflections = dependencies.memoryRepository.savedReflectionsForHome(referenceDate: date)
        guard !savedReflections.isEmpty else { return [] }

        return savedReflections.enumerated().map { index, reflection in
            let itemID = "saved-reflection-\(reflection.id.uuidString)"
            let prominence = dependencies.prominenceEngine.prominence(for: .phaseReflection, reflection: reflection)
            let resolvedState = dependencies.stateRepository.resolvedState(
                compositionKey: compositionContext.compositionKey,
                itemKey: itemID,
                fallbackSpan: prominence.fallbackSpan,
                fallbackZIndex: prominence.fallbackZIndex,
                fallbackRotationDegrees: stickerRotation(for: itemID),
                fallbackScale: stickerScale(for: itemID)
            )

            return (
                order: prominence.order + Double(index) * 0.001,
                item: GridItem(
                    id: itemID,
                    projectionTargetType: CompositionProjectionTargetType.reflection.rawValue,
                    projectionTargetID: reflection.id,
                    recordID: reflection.sourceRecordIDs.first ?? UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
                    card: AnyView(
                        NavigationLink(destination: ReflectionDetailView(reflection: reflection)) {
                            PhaseReflectionCard(data: reflectionCardData(for: reflection))
                        }
                        .buttonStyle(.plain)
                    ),
                    columns: resolvedState.span.widthColumns,
                    units: resolvedState.span.heightUnits,
                    zIndex: resolvedState.zIndex,
                    rotationDegrees: resolvedState.rotationDegrees,
                    scale: resolvedState.scale,
                    availableSpans: availableSpans(for: "text"),
                    deleteActionTitle: "Dismiss Reflection",
                    deleteActionSystemImage: "archivebox",
                    onResize: { newSpan in
                        resizeReflectionCard(reflection, to: newSpan, on: date)
                    },
                    onDelete: {
                        dependencies.memoryRepository.dismissReflection(reflection.id)
                    }
                )
            )
        }
    }

    private func buildTemporalArcEntries(
        date: Date,
        compositionContext: CompositionStateRepository.ResolvedCompositionContext
    ) -> [(order: Double, item: GridItem)] {
        guard let arc = dependencies.memoryRepository.featuredTemporalArc(for: date) else { return [] }

        let itemID = "arc-\(arc.id.uuidString)"
        let prominence = dependencies.prominenceEngine.prominence(for: .temporalArc, arc: arc)
        let resolvedState = dependencies.stateRepository.resolvedState(
            compositionKey: compositionContext.compositionKey,
            itemKey: itemID,
            fallbackSpan: prominence.fallbackSpan,
            fallbackZIndex: prominence.fallbackZIndex,
            fallbackRotationDegrees: stickerRotation(for: itemID),
            fallbackScale: stickerScale(for: itemID)
        )

        return [
            (
                order: prominence.order,
                item: GridItem(
                    id: itemID,
                    projectionTargetType: CompositionProjectionTargetType.arc.rawValue,
                    projectionTargetID: arc.id,
                    recordID: arc.sourceRecordIDs.first ?? UUID(),
                    card: AnyView(
                        NavigationLink(destination: TemporalArcDetailView(arc: arc)) {
                            TemporalArcCard(data: temporalArcCardData(for: arc))
                        }
                        .buttonStyle(.plain)
                    ),
                    columns: resolvedState.span.widthColumns,
                    units: resolvedState.span.heightUnits,
                    zIndex: resolvedState.zIndex,
                    rotationDegrees: resolvedState.rotationDegrees,
                    scale: resolvedState.scale,
                    availableSpans: availableSpans(for: "text"),
                    deleteActionTitle: "Archive Phase",
                    deleteActionSystemImage: "archivebox",
                    onResize: { newSpan in
                        resizeTemporalArcCard(arc, to: newSpan, on: date)
                    },
                    onDelete: {
                        dependencies.memoryRepository.archiveTemporalArc(arc.id)
                    }
                )
            )
        ]
    }

    private func buildPhaseReflectionEntries(
        date: Date,
        compositionContext: CompositionStateRepository.ResolvedCompositionContext
    ) -> [(order: Double, item: GridItem)] {
        guard let arc = dependencies.memoryRepository.featuredTemporalArc(for: date),
              let reflection = dependencies.memoryRepository.linkedReflection(forArcID: arc.id)
        else { return [] }

        let itemID = "reflection-\(reflection.id.uuidString)"
        let prominence = dependencies.prominenceEngine.prominence(for: .phaseReflection, reflection: reflection)
        let resolvedState = dependencies.stateRepository.resolvedState(
            compositionKey: compositionContext.compositionKey,
            itemKey: itemID,
            fallbackSpan: prominence.fallbackSpan,
            fallbackZIndex: prominence.fallbackZIndex,
            fallbackRotationDegrees: stickerRotation(for: itemID),
            fallbackScale: stickerScale(for: itemID)
        )

        return [
            (
                order: prominence.order,
                item: GridItem(
                    id: itemID,
                    projectionTargetType: CompositionProjectionTargetType.reflection.rawValue,
                    projectionTargetID: reflection.id,
                    recordID: reflection.sourceRecordIDs.first ?? UUID(),
                    card: AnyView(
                        NavigationLink(destination: ReflectionDetailView(reflection: reflection)) {
                            PhaseReflectionCard(data: reflectionCardData(for: reflection, linkedArc: arc))
                        }
                        .buttonStyle(.plain)
                    ),
                    columns: resolvedState.span.widthColumns,
                    units: resolvedState.span.heightUnits,
                    zIndex: resolvedState.zIndex,
                    rotationDegrees: resolvedState.rotationDegrees,
                    scale: resolvedState.scale,
                    availableSpans: availableSpans(for: "text"),
                    deleteActionTitle: "Archive Reflection Phase",
                    deleteActionSystemImage: "archivebox",
                    onResize: { newSpan in
                        resizePhaseReflectionCard(reflection, to: newSpan, on: date)
                    },
                    onDelete: {
                        dependencies.memoryRepository.archiveTemporalArc(arc.id)
                    }
                )
            )
        ]
    }

    private func orderedRecords(_ records: [Record]) -> [Record] {
        records.sorted { normalizedOrder(for: $0) < normalizedOrder(for: $1) }
    }

    private func normalizedOrder(for record: Record) -> Double {
        record.dashboardOrder == 0 ? record.createdAt.timeIntervalSince1970 : record.dashboardOrder
    }

    private func allRecordsForSameMonthDay(date: Date) -> [Record] {
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
        let candidates = (try? dependencies.modelContext.fetch(descriptor)) ?? []
        return candidates.filter {
            calendar.component(.month, from: $0.createdAt) == month
                && calendar.component(.day, from: $0.createdAt) == day
                && calendar.component(.year, from: $0.createdAt) < currentYear
        }
    }

    private func temporalArcCardData(for arc: TemporalArc) -> TemporalArcCardData {
        TemporalArcCardData(
            title: arc.title,
            summary: arc.summary,
            dominantTheme: arc.dominantTheme,
            dominantEntityName: arc.dominantEntityName,
            dateRangeText: temporalArcDateRangeText(for: arc),
            recordCount: arc.sourceRecordIDs.count,
            artifactCount: arc.sourceArtifactIDs.count
        )
    }

    private func reflectionCardData(for reflection: ReflectionSnapshot, linkedArc: TemporalArc? = nil) -> PhaseReflectionCardData {
        PhaseReflectionCardData(
            title: reflection.title,
            body: reflection.body,
            phaseTitle: linkedArc?.title ?? reflectionContextTitle(for: reflection),
            dateText: reflectionDateText(for: reflection, linkedArc: linkedArc),
            recordCount: reflection.sourceRecordIDs.count
        )
    }

    private func reflectionContextTitle(for reflection: ReflectionSnapshot) -> String {
        let trimmed = reflection.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Saved Reflection" : trimmed
    }

    private func reflectionDateText(for reflection: ReflectionSnapshot, linkedArc: TemporalArc?) -> String {
        if let linkedArc {
            return temporalArcDateRangeText(for: linkedArc)
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        if let savedAt = reflection.savedAt {
            return "Saved \(formatter.string(from: savedAt))"
        }
        return formatter.string(from: reflection.createdAt)
    }

    private func temporalArcDateRangeText(for arc: TemporalArc) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: arc.startDate, to: arc.endDate)
    }

    private func localizedDate(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
