import SwiftUI

struct HomeScreen: View {
    enum Surface {
        case home
        case memories

        var navigationTitle: String {
            switch self {
            case .home:
                return "Home"
            case .memories:
                return "Memories"
            }
        }

        var emptyTitle: String {
            switch self {
            case .home:
                return "No memories yet"
            case .memories:
                return "Your memory library is empty"
            }
        }

        var emptyDescription: String {
            switch self {
            case .home:
                return "Your first capture will immediately land in the new memory stack."
            case .memories:
                return "New captures will accumulate here as a persistent memory library."
            }
        }
    }

    @Environment(\.memoryRepository) private var memoryRepository

    let surface: Surface

    @State private var memories: [MemorySummary] = []
    @State private var homeBoard: HomeBoardSnapshot?
    @State private var pipelineStatuses: [PipelineStatusSummary] = []
    @State private var isPresentingComposer = false
    @State private var errorMessage: String?

    init(surface: Surface = .home) {
        self.surface = surface
    }

    var body: some View {
        List {
            if surface == .home {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Capture")
                            .font(.title2.weight(.semibold))
                        Text("Save something quickly and let it appear in your memory space immediately.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            isPresentingComposer = true
                        } label: {
                            Label("New Memory", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 8)
                }

                Section("Today Board") {
                    if let homeBoard, !homeBoard.items.isEmpty {
                        HomeBoardSection(board: homeBoard)
                    } else {
                        Text("Your day board will fill as captures land in the composition layer.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Pipeline Status") {
                    if pipelineStatuses.isEmpty {
                        Text("Capture pipeline status will appear here once local memories start accumulating.")
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

            Section(surface == .home ? "Recent" : "All Memories") {
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
                        Label("Capture", systemImage: "plus")
                    }
                }
            }
        }
        .task {
            await reload()
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

    private func reload() async {
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
                Text("\(summary.artifactCount) artifact\(summary.artifactCount == 1 ? "" : "s")")
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
                    CompositionMemoryCard(item: item)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CompositionMemoryCard: View {
    let item: HomeBoardItemSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch item.renderValue {
            case let .memory(memory):
                Text(memory.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(memory.summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text(memory.record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case let .arc(arc):
                Text(arc.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(arc.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text(arc.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case let .reflection(reflection):
                Text(reflection.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(reflection.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text(reflection.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case let .system(title, subtitle):
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text(item.compositionItem.itemKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: heightForItem(item.compositionItem))
        .background(backgroundForItem(item.compositionItem))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .rotationEffect(.degrees(item.compositionItem.rotationDegrees))
        .scaleEffect(item.compositionItem.scale)
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
