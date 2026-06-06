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

    let surface: Surface

    @State private var memories: [MemorySummary] = []
    @State private var homeBoard: HomeBoardSnapshot?
    @State private var isPresentingComposer = false
    @State private var isReloading = false
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
        .fullScreenCover(isPresented: $isPresentingComposer) {
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
                homeBoard = try memoryRepository.fetchHomeBoard(for: .now, limit: 8)
            } else {
                memories = try memoryRepository.fetchRecentMemories(limit: nil)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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
