import SwiftUI

private struct HomeBoardActionContext: Identifiable {
    let item: HomeBoardItemSnapshot

    var id: UUID { item.id }
}

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
    @State private var dailyQuestionPreparationEvidenceSignature: String?
    @State private var errorMessage: String?
    @State private var selectedRoute: HomeRoute?
    @State private var homeBoardActionContext: HomeBoardActionContext?
    @State private var homeBoardReasonItem: HomeBoardItemSnapshot?
    @Binding private var requestedRoute: HomeRoute?
    @Binding private var isEditingHomeBoard: Bool

    init(
        surface: Surface = .home,
        requestedRoute: Binding<HomeRoute?> = .constant(nil),
        isEditingHomeBoard: Binding<Bool> = .constant(false)
    ) {
        self.surface = surface
        _requestedRoute = requestedRoute
        _isEditingHomeBoard = isEditingHomeBoard
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
                    .moryHidesTabChrome()
            case let .arc(arcID):
                ArcDetailView(arcID: arcID)
                    .moryHidesTabChrome()
            case let .reflection(reflectionID):
                ReflectionDetailView(reflectionID: reflectionID)
                    .moryHidesTabChrome()
            case let .question(questionID):
                ClarificationQuestionDetailView(questionID: questionID)
                    .moryHidesTabChrome()
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
        .confirmationDialog(
            "Card actions",
            isPresented: isShowingHomeBoardActionDialog,
            titleVisibility: .hidden
        ) {
            if let item = homeBoardActionContext?.item {
                homeBoardActionButtons(for: item)
            }
        } message: {
            if let item = homeBoardActionContext?.item {
                Text(verbatim: HomeBoardCardMetadata(item: item).title)
            }
        }
        .alert(Text(verbatim: "Why this appears"), isPresented: isShowingHomeBoardReasonAlert) {
            Button {
            } label: {
                Text(verbatim: "OK")
            }
        } message: {
            if let item = homeBoardReasonItem {
                Text(verbatim: homeBoardReasonDetail(for: item))
            }
        }
        .onAppear {
            consumeRequestedRouteIfNeeded()
        }
        .onChange(of: requestedRoute) { _, _ in
            consumeRequestedRouteIfNeeded()
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
                        onShowActions: showHomeBoardActions,
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
            guard homeBoardActionContext == nil, homeBoardReasonItem == nil else { continue }
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

            _ = try? await DailyQuestionSuggestionService(
                cloudIntelligenceService: cloudIntelligenceService
            )
            .prepareIfNeeded(repository: memoryRepository)
            _ = try? await NotificationOrchestrator().orchestrate(
                trigger: .homeForegroundRefresh,
                repository: memoryRepository
            )
        } catch {
            // Home remains usable when intelligence preparation or scheduling is unavailable.
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

    private func showHomeBoardActions(for item: HomeBoardItemSnapshot) {
        homeBoardActionContext = HomeBoardActionContext(item: item)
    }

    @ViewBuilder
    private func homeBoardActionButtons(for item: HomeBoardItemSnapshot) -> some View {
        Button {
            homeBoardActionContext = nil
            homeBoardReasonItem = item
        } label: {
            Text(verbatim: "Explain why")
        }

        if item.layout.layer == .suggestion {
            Button {
                performHomeBoardAction(for: item) {
                    updateBoardPreference(item, action: .addToBoard)
                }
            } label: {
                Text(verbatim: "Add to board")
            }
        }

        Button {
            performHomeBoardAction(for: item) {
                updateBoardPreference(item, action: .preferMore)
            }
        } label: {
            Text(verbatim: "More like this")
        }

        Button {
            performHomeBoardAction(for: item) {
                updateBoardPreference(item, action: .preferLess)
            }
        } label: {
            Text(verbatim: "Less like this")
        }

        if item.layout.feedbackAdjustment != 0 {
            Button {
                performHomeBoardAction(for: item) {
                    updateBoardPreference(item, action: .resetFeedback)
                }
            } label: {
                Text(verbatim: "Reset feedback")
            }
        }

        if item.cardKind != .clarificationQuestion {
            Button {
                performHomeBoardAction(for: item) {
                    updateBoardPreference(item, action: .pin(!item.isPinned))
                }
            } label: {
                Text(item.isPinned ? "home.board.action.unpin" : "home.board.action.pin")
            }
        }

        if isEditingHomeBoard {
            Button {
                performHomeBoardAction(for: item) {
                    moveHomeBoardItem(item, direction: .earlier)
                }
            } label: {
                Text(verbatim: "Move earlier")
            }
            .disabled(!canMoveHomeBoardItem(item, direction: .earlier))

            Button {
                performHomeBoardAction(for: item) {
                    moveHomeBoardItem(item, direction: .later)
                }
            } label: {
                Text(verbatim: "Move later")
            }
            .disabled(!canMoveHomeBoardItem(item, direction: .later))

            ForEach(HomeBoardSpan.allowedSizes, id: \.self) { span in
                Button {
                    performHomeBoardAction(for: item) {
                        updateBoardPreference(item, action: .resize(span))
                    }
                } label: {
                    Text(verbatim: "Resize to \(span.widthColumns)x\(span.heightUnits)")
                }
                .disabled(span == item.layout.span)
            }
        }

        Button(role: .destructive) {
            performHomeBoardAction(for: item) {
                if case let .clarificationQuestion(question, _) = item.renderValue {
                    dismissQuestion(question)
                } else {
                    updateBoardPreference(item, action: item.layout.layer == .suggestion ? .dismiss : .hide)
                }
            }
        } label: {
            Text(item.layout.layer == .suggestion || item.cardKind == .clarificationQuestion ? "home.board.action.dismiss" : "home.board.action.hide")
        }

        Button("common.cancel", role: .cancel) {
            homeBoardActionContext = nil
        }
    }

    private var isShowingHomeBoardActionDialog: Binding<Bool> {
        Binding(
            get: { homeBoardActionContext != nil },
            set: { isShowing in
                if !isShowing {
                    homeBoardActionContext = nil
                }
            }
        )
    }

    private var isShowingHomeBoardReasonAlert: Binding<Bool> {
        Binding(
            get: { homeBoardReasonItem != nil },
            set: { isShowing in
                if !isShowing {
                    homeBoardReasonItem = nil
                }
            }
        )
    }

    private func performHomeBoardAction(for item: HomeBoardItemSnapshot, _ action: () -> Void) {
        guard homeBoardActionContext?.item.id == item.id else { return }
        homeBoardActionContext = nil
        action()
    }

    private func canMoveHomeBoardItem(_ item: HomeBoardItemSnapshot, direction: HomeBoardMoveDirection) -> Bool {
        guard let items = homeBoard?.userBoardItems, item.layout.layer == .userBoard else { return false }
        return HomeBoardOrdering.canMove(item: item, in: items, direction: direction)
    }

    private func moveHomeBoardItem(_ item: HomeBoardItemSnapshot, direction: HomeBoardMoveDirection) {
        guard let items = homeBoard?.userBoardItems else { return }
        updateBoardOrder(HomeBoardOrdering.updatesForMove(items: items, moving: item, direction: direction))
    }

    private func homeBoardReasonDetail(for item: HomeBoardItemSnapshot) -> String {
        var lines = [item.reason.ifEmpty("recent activity")]
        if !item.sourceRecordIDs.isEmpty {
            lines.append("\(item.sourceRecordIDs.count) source memories")
        }
        if item.layout.feedbackAdjustment > 0 {
            lines.append("You asked for more like this.")
        } else if item.layout.feedbackAdjustment < 0 {
            lines.append("You asked for less like this.")
        }
        return lines.joined(separator: "\n")
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

    private func consumeRequestedRouteIfNeeded() {
        guard let requestedRoute else { return }
        selectedRoute = requestedRoute
        self.requestedRoute = nil
    }
}

enum HomeRoute: Hashable, Identifiable, Sendable {
    case memory(UUID)
    case arc(UUID)
    case reflection(UUID)
    case question(UUID)

    var id: String {
        switch self {
        case let .memory(id): return "memory-\(id.uuidString)"
        case let .arc(id): return "arc-\(id.uuidString)"
        case let .reflection(id): return "reflection-\(id.uuidString)"
        case let .question(id): return "question-\(id.uuidString)"
        }
    }
}

struct ClarificationQuestionDetailView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let questionID: UUID

    @State private var question: ClarificationQuestion?
    @State private var profile: EntityProfile?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let question {
                Section {
                    if question.status == .pending {
                        ClarificationQuestionCard(
                            question: question,
                            profile: profile,
                            onAnswer: answerQuestion,
                            onDismiss: dismissQuestion
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(question.prompt)
                                .font(.headline)
                            Text(question.status.displayLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let answer = question.answer {
                                Text(answer.freeformText ?? answer.value)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else if errorMessage == nil {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Daily question")
        .moryHidesTabChrome()
        .task {
            load()
        }
        .refreshable {
            load()
        }
    }

    private func load() {
        do {
            let questions = try memoryRepository.fetchClarificationQuestions(status: nil, limit: nil)
            question = questions.first { $0.id == questionID }
            if let question, question.targetType == .entity {
                profile = try memoryRepository.fetchEntityProfile(entityID: question.targetID)
            } else {
                profile = nil
            }
            errorMessage = question == nil ? "Question is no longer available." : nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func answerQuestion(_ answer: ClarificationAnswer) {
        do {
            try memoryRepository.answerClarificationQuestion(questionID, answer: answer)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func dismissQuestion() {
        do {
            try memoryRepository.dismissClarificationQuestion(questionID)
            load()
        } catch {
            errorMessage = error.localizedDescription
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
    let onShowActions: (HomeBoardItemSnapshot) -> Void
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
                    onShowActions: onShowActions,
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
                        onShowActions: onShowActions,
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
    let onShowActions: (HomeBoardItemSnapshot) -> Void
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
                    onShowActions: onShowActions,
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
