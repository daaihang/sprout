import SwiftUI

struct HomeScreen: View {
    enum Surface {
        case home
        case memories

        var navigationTitle: String {
            switch self {
            case .home:
                return String(localized: "home.nav.title")
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
                        Text("home.capture.description")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            isPresentingComposer = true
                        } label: {
                            Label("home.capture.button", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 8)
                }

                Section("home.section.board") {
                    if let homeBoard, !homeBoard.items.isEmpty {
                        HomeBoardSection(board: homeBoard)
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
                                Text(item.status.userLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let lastError = item.status.lastError?.trimmedOrNil {
                                    Text(lastError)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 2)
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text(surface.emptyTitle)
                            .font(.headline)
                        Text(surface.emptyDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(memories) { memory in
                        NavigationLink {
                            MemoryDetailView(recordID: memory.id)
                        } label: {
                            MemoryRow(summary: memory)
                        }
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
        .toolbar {
            if surface == .memories {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingComposer = true
                    } label: {
                        Label("home.capture.title", systemImage: "plus")
                    }
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
            CaptureComposerView {
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
}

private struct MemoryRow: View {
    let summary: MemorySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(summary.title)
                .font(.headline)
                .lineLimit(2)

            Text(summary.summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: 10) {
                Text(summary.record.captureSource.rawValue)
                if let mood = summary.record.userMood?.trimmedOrNil {
                    Text(mood)
                }
                Text("memory.row.attachments \(summary.artifactCount)")
                if let pipelineStatus = summary.pipelineStatus {
                    Text(pipelineStatus.userLabel)
                }
                Text(summary.record.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct HomeBoardSection: View {
    let board: HomeBoardSnapshot

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
                    CompositionBoardCard(item: item)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CompositionBoardCard: View {
    let item: HomeBoardItemSnapshot

    var body: some View {
        Group {
            switch item.renderValue {
            case let .memory(memory):
                NavigationLink {
                    MemoryDetailView(recordID: memory.record.id)
                } label: {
                    cardBody
                }
                .buttonStyle(.plain)
            case let .arc(arc):
                NavigationLink {
                    ArcDetailView(arcID: arc.id)
                } label: {
                    cardBody
                }
                .buttonStyle(.plain)
            case let .reflection(reflection):
                NavigationLink {
                    ReflectionDetailView(reflectionID: reflection.id)
                } label: {
                    cardBody
                }
                .buttonStyle(.plain)
            case .system:
                cardBody
            }
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch item.renderValue {
            case let .memory(memory):
                Text(memory.title).font(.headline).lineLimit(2)
                Text(memory.summaryText).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                if let contextSummary = contextSummary(for: memory) {
                    Text(contextSummary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Text(memory.record.updatedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
            case let .arc(arc):
                Text(arc.title).font(.headline).lineLimit(2)
                Text(arc.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                Text("home.board.arc.ongoing \(arc.sourceRecordIDs.count)").font(.caption).foregroundStyle(.secondary)
            case let .reflection(reflection):
                Text(reflection.title).font(.headline).lineLimit(2)
                Text(reflection.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                Text(reflection.statusLabel).font(.caption).foregroundStyle(.secondary)
            case let .system(title, subtitle):
                Text(title).font(.headline).lineLimit(2)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                Text(item.compositionItem.itemKey).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: heightForItem(item.compositionItem))
        .background(backgroundForItem(item.compositionItem))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .rotationEffect(.degrees(item.compositionItem.rotationDegrees))
        .scaleEffect(item.compositionItem.scale)
    }

    private func contextSummary(for memory: MemorySummary) -> String? {
        memory.contextArtifacts
            .map(\.summary)
            .compactMap(\.trimmedOrNil)
            .prefix(3)
            .joined(separator: " | ")
            .trimmedOrNil
    }

    private func heightForItem(_ item: CompositionItem) -> CGFloat {
        CGFloat(max(1, item.heightUnits)) * 110
    }

    private func backgroundForItem(_ item: CompositionItem) -> some ShapeStyle {
        let palette: [Color] = [
            Color(red: 0.95, green: 0.89, blue: 0.79),
            Color(red: 0.84, green: 0.92, blue: 0.88),
            Color(red: 0.92, green: 0.86, blue: 0.90),
            Color(red: 0.88, green: 0.90, blue: 0.96),
        ]
        return palette[item.zIndex % palette.count].gradient
    }
}
