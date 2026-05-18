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

    let surface: Surface

    @State private var memories: [MemorySummary] = []
    @State private var homeBoard: HomeBoardSnapshot?
    @State private var pipelineStatuses: [PipelineStatusSummary] = []
    @State private var isPresentingComposer = false
    @State private var isReloading = false
    @State private var errorMessage: String?
    @State private var selectedRoute: HomeRoute?

    init(surface: Surface = .home) {
        self.surface = surface
    }

    var body: some View {
        List {
            if surface == .home {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("home.capture.title")
                            .font(.title2.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("home.capture.description")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            isPresentingComposer = true
                        } label: {
                            Label("home.capture.button", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .moryCard(tone: .memory)
                }

                Section("home.section.board") {
                    if let homeBoard, !homeBoard.items.isEmpty {
                        HomeBoardSection(
                            board: homeBoard,
                            onSelect: { route in
                            selectedRoute = route
                            },
                            onPreference: updateBoardPreference,
                            onSystemAction: { isPresentingComposer = true }
                        )
                    } else {
                        Text("home.board.empty")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("home.section.pipeline") {
                    if pipelineStatuses.isEmpty {
                        Text("home.pipeline.empty")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pipelineStatuses) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(item.status.userLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if item.status.stage == .failed {
                                    Text("empty.processingFailed.message")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .moryCard(tone: item.status.stage == .failed ? .warning : .neutral)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section(surface == .home ? String(localized: "home.section.recent") : String(localized: "memories.section.all")) {
                if memories.isEmpty {
                    MoryPublicEmptyStateView(
                        state: surface == .home ? .today : .memories,
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
            if surface == .memories {
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
            memories = try memoryRepository.fetchRecentMemories(limit: nil)
            if surface == .home {
                homeBoard = try memoryRepository.fetchHomeBoard(for: .now, limit: 8)
                pipelineStatuses = try memoryRepository.fetchPipelineStatusSummaries(limit: 8)
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
}

private enum HomeRoute: Hashable, Identifiable {
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
        .moryCard(tone: .memory)
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
    let onSelect: (HomeRoute) -> Void
    let onPreference: (HomeBoardItemSnapshot, HomeBoardPreferenceAction) -> Void
    let onSystemAction: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(board.board.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(board.items) { item in
                    HomeBoardCard(
                        item: item,
                        onSelect: onSelect,
                        onPreference: onPreference,
                        onSystemAction: onSystemAction
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HomeBoardCard: View {
    let item: HomeBoardItemSnapshot
    let onSelect: (HomeRoute) -> Void
    let onPreference: (HomeBoardItemSnapshot, HomeBoardPreferenceAction) -> Void
    let onSystemAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    Label(cardLabel, systemImage: cardIcon)
                        .moryPill(tone: cardTone)
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    preferenceMenu
                }
                VStack(alignment: .leading, spacing: 6) {
                    Label(cardLabel, systemImage: cardIcon)
                        .moryPill(tone: cardTone)
                    HStack {
                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        preferenceMenu
                    }
                }
            }

            switch item.renderValue {
            case let .memory(memory):
                Button {
                    onSelect(.memory(memory.record.id))
                } label: {
                    MemoryBoardCard(memory: memory, reason: item.reason)
                }
                .buttonStyle(.plain)
            case let .arc(arc):
                Button {
                    onSelect(.arc(arc.id))
                } label: {
                    ArcBoardCard(arc: arc, reason: item.reason)
                }
                .buttonStyle(.plain)
            case let .reflection(reflection):
                Button {
                    onSelect(.reflection(reflection.id))
                } label: {
                    ReflectionBoardCard(reflection: reflection, reason: item.reason)
                }
                .buttonStyle(.plain)
            case let .systemPrompt(title, subtitle, actionTitle):
                SystemPromptBoardCard(
                    title: title,
                    subtitle: subtitle,
                    actionTitle: actionTitle,
                    onAction: onSystemAction
                )
            case let .contextCluster(title, subtitle, sourceRecordIDs):
                ContextClusterBoardCard(title: title, subtitle: subtitle, recordCount: sourceRecordIDs.count)
            case let .pendingAction(title, subtitle, targetRecordID):
                Button {
                    if let targetRecordID {
                        onSelect(.memory(targetRecordID))
                    }
                } label: {
                    PendingActionBoardCard(title: title, subtitle: subtitle)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, minHeight: heightForItem(item.compositionItem))
        .moryCard(tone: cardTone)
        .rotationEffect(.degrees(item.compositionItem.rotationDegrees))
        .scaleEffect(item.compositionItem.scale)
        .accessibilityElement(children: .combine)
    }

    private var preferenceMenu: some View {
        Menu {
            Button {
                onPreference(item, .pin(!item.isPinned))
            } label: {
                Label(item.isPinned ? "home.board.action.unpin" : "home.board.action.pin", systemImage: item.isPinned ? "pin.slash" : "pin")
            }

            Button(role: .destructive) {
                onPreference(item, item.cardKind == .systemPrompt || item.cardKind == .reflection ? .dismiss : .hide)
            } label: {
                Label(item.cardKind == .systemPrompt || item.cardKind == .reflection ? "home.board.action.dismiss" : "home.board.action.hide", systemImage: "eye.slash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.button)
    }

    private var cardLabel: String {
        switch item.cardKind {
        case .memory: return String(localized: "home.board.kind.memory")
        case .arc: return String(localized: "home.board.kind.arc")
        case .reflection: return String(localized: "home.board.kind.reflection")
        case .systemPrompt: return String(localized: "home.board.kind.system")
        case .contextCluster: return String(localized: "home.board.kind.cluster")
        case .pendingAction: return String(localized: "home.board.kind.pending")
        }
    }

    private var cardIcon: String {
        switch item.cardKind {
        case .memory: return "doc.text"
        case .arc: return "point.3.connected.trianglepath.dotted"
        case .reflection: return "sparkles"
        case .systemPrompt: return "hand.wave"
        case .contextCluster: return "square.stack.3d.up"
        case .pendingAction: return "exclamationmark.circle"
        }
    }

    private var cardTone: MoryCardTone {
        switch item.cardKind {
        case .memory: return .memory
        case .arc: return .storyline
        case .reflection: return .reflection
        case .systemPrompt: return .warning
        case .contextCluster: return .entity
        case .pendingAction: return .warning
        }
    }

    private func heightForItem(_ item: CompositionItem) -> CGFloat {
        CGFloat(max(1, item.heightUnits)) * 110
    }
}

private struct MemoryBoardCard: View {
    let memory: MemorySummary
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(memory.title).font(.headline).lineLimit(2)
            Text(memory.summaryText).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            if let contextSummary {
                Text(contextSummary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            HStack {
                Text(reason)
                Spacer()
                Text(memory.record.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var contextSummary: String? {
        memory.contextArtifacts
            .map(\.summary)
            .compactMap(\.trimmedOrNil)
            .prefix(3)
            .joined(separator: " | ")
            .trimmedOrNil
    }
}

private struct ArcBoardCard: View {
    let arc: TemporalArc
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(arc.title).font(.headline).lineLimit(2)
            Text(arc.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            HStack {
                Text("home.board.arc.ongoing \(arc.sourceRecordIDs.count)")
                Spacer()
                Text(reason)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct ReflectionBoardCard: View {
    let reflection: ReflectionSnapshot
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reflection.title).font(.headline).lineLimit(2)
            Text(reflection.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            HStack {
                Text(reflection.statusLabel)
                Spacer()
                Text(reason)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct SystemPromptBoardCard: View {
    let title: String
    let subtitle: String
    let actionTitle: String?
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).lineLimit(2)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            if let actionTitle {
                Button(actionTitle, action: onAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct ContextClusterBoardCard: View {
    let title: String
    let subtitle: String
    let recordCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).lineLimit(2)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            Text("home.board.cluster.count \(recordCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PendingActionBoardCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).lineLimit(2)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
        }
    }
}
