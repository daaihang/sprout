import SwiftData
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

    @Environment(\.modelContext) private var modelContext

    let surface: Surface

    @State private var memories: [MemorySummary] = []
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
            let repository = MoryMemoryRepository(modelContext: modelContext)
            memories = try repository.fetchRecentMemories()
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
                Text(summary.record.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
private extension String {
    var trimmedOrNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
