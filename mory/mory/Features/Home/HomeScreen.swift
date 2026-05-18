import SwiftUI

struct HomeScreen: View {
    enum Surface {
        case home
        case memories

        var navigationTitle: String {
            switch self {
            case .home:
                return String(localized: "tab.today")
            case .memories:
                return String(localized: "memories.nav.title")
            }
        }

        var emptyTitle: String {
            switch self {
            case .home:
                return String(localized: "home.empty.title")
            case .memories:
                return String(localized: "memories.empty.title")
            }
        }

        var emptyDescription: String {
            switch self {
            case .home:
                return String(localized: "home.empty.description")
            case .memories:
                return String(localized: "memories.empty.description")
            }
        }
    }

    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.cloudIntelligenceService) private var cloudIntelligenceService

    let surface: Surface

    @State private var memories: [MemorySummary] = []
    @State private var homeBoard: HomeBoardSnapshot?
    @State private var isPresentingComposer = false
    @State private var isReloading = false
    @State private var isEditingHomeBoard = false
    @State private var dailyQuestionPreparationEvidenceSignature: String?
    @State private var errorMessage: String?
    @State private var selectedRoute: HomeRoute?

    init(surface: Surface = .home) {
        self.surface = surface
    }

    var body: some View {
        Group {
            switch surface {
            case .home:
                homeSurface
            case .memories:
                memoriesSurface
            }
        }
        .navigationTitle(surface.navigationTitle)
        .navigationDestination(item: $selectedRoute) { route in
            switch route {
            case let .memory(recordID):
                MemoryDetailView(recordID: recordID)
            case let .arc(arcID):
                ArcDetailView(arcID: arcID)
            case let .reflection(reflectionID):
                ReflectionDetailView(reflectionID: reflectionID)
            }
        }
        .toolbar {
            if surface == .home {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isEditingHomeBoard.toggle()
                    } label: {
                        Text(verbatim: isEditingHomeBoard ? "Done" : "Edit")
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingComposer = true
                    } label: {
                        Label("home.capture.title", systemImage: "plus")
                    }
                    .accessibilityLabel(Text("home.capture.title"))
                    .accessibilityHint(Text("empty.action.addMemory"))
                }
            }
        }
        .task {
            await autoRefresh()
        }
        .refreshable {
            await reload()
        }
        .sheet(isPresented: $isPresentingComposer) {
            UnifiedCaptureComposerView(seed: .empty) {
                Task { await reload() }
            }
        }
    }

    private var homeSurface: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MorySpacing.large) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let homeBoard, !homeBoard.items.isEmpty {
                    VStack(alignment: .leading, spacing: MorySpacing.xSmall) {
                        Text("home.section.board")
                            .font(.headline)
                        if let subtitle = homeBoard.board.subtitle.trimmedOrNil {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HomeBoardSection(
                        board: homeBoard,
                        isEditing: isEditingHomeBoard,
                        onSelect: { route in
                            selectedRoute = route
                        },
                        onPreference: updateBoardPreference,
                        onReorder: updateBoardOrder,
                        onAnswerQuestion: answerQuestion,
                        onDismissQuestion: dismissQuestion,
                        onSystemAction: { isPresentingComposer = true }
                    )
                } else {
                    MoryPublicEmptyStateView(
                        state: .today,
                        onAction: { isPresentingComposer = true }
                    )
                }
            }
            .padding(.horizontal, MorySpacing.medium)
            .padding(.vertical, MorySpacing.medium)
        }
    }

    private var memoriesSurface: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section(String(localized: "memories.section.all")) {
                if memories.isEmpty {
                    MoryPublicEmptyStateView(
                        state: .memories,
                        onAction: { isPresentingComposer = true }
                    )
                } else {
                    ForEach(memories) { memory in
                        Button {
                            selectedRoute = .memory(memory.id)
                        } label: {
                            MemoryRow(summary: memory)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteMemory(recordID: memory.id)
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func autoRefresh() async {
        await reload()

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { break }
            await reload()
        }
    }

    @MainActor
    private func reload() async {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }

        do {
            if surface == .home {
                await prepareDailyQuestionIfNeeded()
                homeBoard = try memoryRepository.fetchHomeBoard(for: .now, limit: 8)
            } else {
                memories = try memoryRepository.fetchRecentMemories(limit: nil)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func prepareDailyQuestionIfNeeded() async {
        do {
            let memorySignature = try memoryRepository.fetchRecentMemories(limit: 6)
                .map { $0.id.uuidString }
                .joined(separator: ",")
            guard !memorySignature.isEmpty else { return }

            let preferences = try memoryRepository.fetchIntelligencePreferences()
            let flags = try memoryRepository.fetchV6FeatureFlags()
            let evidenceSignature = [
                memorySignature,
                String(preferences.updatedAt.timeIntervalSince1970),
                String(flags.updatedAt.timeIntervalSince1970),
            ].joined(separator: "|")
            guard evidenceSignature != dailyQuestionPreparationEvidenceSignature else {
                return
            }
            dailyQuestionPreparationEvidenceSignature = evidenceSignature

            _ = try await DailyQuestionSuggestionService(
                cloudIntelligenceService: cloudIntelligenceService
            )
            .prepareIfNeeded(repository: memoryRepository)
        } catch {
            // Home remains usable when cloud question preparation is unavailable.
        }
    }

    private func deleteMemory(recordID: UUID) {
        do {
            try memoryRepository.deleteMemory(recordID: recordID)
            memories.removeAll { $0.id == recordID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateBoardPreference(_ item: HomeBoardItemSnapshot, action: HomeBoardPreferenceAction) {
        do {
            try memoryRepository.updateHomeBoardItemPreference(item, action: action)
            Task { await reload() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateBoardOrder(_ updates: [HomeBoardOrderUpdate]) {
        do {
            try memoryRepository.updateHomeBoardItemPreferences(
                updates.map { update in
                    (item: update.item, action: .setUserOrder(update.sortIndex))
                }
            )
            Task { await reload() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func answerQuestion(_ question: ClarificationQuestion, answer: ClarificationAnswer) {
        do {
            try memoryRepository.answerClarificationQuestion(question.id, answer: answer)
            Task { await reload() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func dismissQuestion(_ question: ClarificationQuestion) {
        do {
            try memoryRepository.dismissClarificationQuestion(question.id)
            Task { await reload() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum HomeRoute: Hashable, Identifiable {
    case memory(UUID)
    case arc(UUID)
    case reflection(UUID)

    var id: String {
        switch self {
        case let .memory(id): return "memory-\(id.uuidString)"
        case let .arc(id): return "arc-\(id.uuidString)"
        case let .reflection(id): return "reflection-\(id.uuidString)"
        }
    }
}

private struct MemoryRow: View {
    let summary: MemorySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(summary.title)
                .font(.headline)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(summary.summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                metadataRow
                VStack(alignment: .leading, spacing: MorySpacing.xSmall) {
                    metadataRow
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 10) {
            Text(summary.record.captureSource.presentationLabel)
            if let mood = summary.record.userMood?.trimmedOrNil {
                Text(mood)
            }
            Text("memory.row.attachments \(summary.artifactCount)")
            if let pipelineStatus = summary.pipelineStatus {
                Text(pipelineStatus.userLabel)
            }
            Text(summary.record.updatedAt.formatted(date: .abbreviated, time: .shortened))
        }
    }
}

private extension CaptureSource {
    var presentationLabel: String {
        switch self {
        case .composer: return String(localized: "capture.source.composer")
        case .voice: return String(localized: "capture.source.voice")
        case .photo: return String(localized: "capture.source.photo")
        case .audio: return String(localized: "capture.source.audio")
        case .importFile: return String(localized: "capture.source.importFile")
        case .manual: return String(localized: "capture.source.manual")
        }
    }
}

private struct HomeBoardSection: View {
    let board: HomeBoardSnapshot
    let isEditing: Bool
    let onSelect: (HomeRoute) -> Void
    let onPreference: (HomeBoardItemSnapshot, HomeBoardPreferenceAction) -> Void
    let onReorder: ([HomeBoardOrderUpdate]) -> Void
    let onAnswerQuestion: (ClarificationQuestion, ClarificationAnswer) -> Void
    let onDismissQuestion: (ClarificationQuestion) -> Void
    let onSystemAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MorySpacing.large) {
            if !board.userBoardItems.isEmpty {
                HomeBoardGrid(
                    items: board.userBoardItems,
                    isEditing: isEditing,
                    onSelect: onSelect,
                    onPreference: onPreference,
                    onReorder: onReorder,
                    onAnswerQuestion: onAnswerQuestion,
                    onDismissQuestion: onDismissQuestion,
                    onSystemAction: onSystemAction
                )
            }

            if !board.suggestionItems.isEmpty {
                VStack(alignment: .leading, spacing: MorySpacing.small) {
                    Text(verbatim: "Suggestions")
                        .font(.headline)
                    HomeBoardGrid(
                        items: board.suggestionItems,
                        isEditing: isEditing,
                        onSelect: onSelect,
                        onPreference: onPreference,
                        onReorder: onReorder,
                        onAnswerQuestion: onAnswerQuestion,
                        onDismissQuestion: onDismissQuestion,
                        onSystemAction: onSystemAction
                    )
                }
                .accessibilityElement(children: .contain)
            }
        }
    }
}

private struct HomeBoardGrid: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let items: [HomeBoardItemSnapshot]
    let isEditing: Bool
    let onSelect: (HomeRoute) -> Void
    let onPreference: (HomeBoardItemSnapshot, HomeBoardPreferenceAction) -> Void
    let onReorder: ([HomeBoardOrderUpdate]) -> Void
    let onAnswerQuestion: (ClarificationQuestion, ClarificationAnswer) -> Void
    let onDismissQuestion: (ClarificationQuestion) -> Void
    let onSystemAction: () -> Void

    var body: some View {
        HomeBoardGridLayout(metrics: metrics) {
            ForEach(items) { item in
                HomeBoardCard(
                    item: item,
                    isEditing: isEditing,
                    orderControls: orderControls(for: item),
                    onSelect: onSelect,
                    onPreference: onPreference,
                    onAnswerQuestion: onAnswerQuestion,
                    onDismissQuestion: onDismissQuestion,
                    onSystemAction: onSystemAction
                )
                .layoutValue(key: HomeBoardSpanKey.self, value: item.layout.span)
                .zIndex(Double(item.compositionItem.zIndex))
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: items.map(\.compositionItem.itemKey))
    }

    private var metrics: HomeBoardGridMetrics {
        HomeBoardGridMetrics(columns: horizontalSizeClass == .regular ? 8 : 4)
    }

    private func orderControls(for item: HomeBoardItemSnapshot) -> HomeBoardOrderControls? {
        guard isEditing, item.layout.layer == .userBoard else { return nil }
        return HomeBoardOrderControls(
            canMoveEarlier: HomeBoardOrdering.canMove(item: item, in: items, direction: .earlier),
            canMoveLater: HomeBoardOrdering.canMove(item: item, in: items, direction: .later),
            moveEarlier: {
                onReorder(HomeBoardOrdering.updatesForMove(items: items, moving: item, direction: .earlier))
            },
            moveLater: {
                onReorder(HomeBoardOrdering.updatesForMove(items: items, moving: item, direction: .later))
            }
        )
    }
}
