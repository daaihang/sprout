import SwiftUI

struct TimelineScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var selectedGranularity: TimelineGranularity = .day
    @State private var timeline: TimelineSnapshot?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker("timeline.granularity", selection: $selectedGranularity) {
                ForEach(TimelineGranularity.allCases) { granularity in
                    Text(granularity.rawValue.capitalized).tag(granularity)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding()
            } else if let timeline {
                if timeline.groups.isEmpty {
                    ContentUnavailableView(
                        "timeline.empty.title",
                        systemImage: "clock",
                        description: Text("timeline.empty.description")
                    )
                } else {
                    List {
                        ForEach(timeline.groups) { group in
                            Section(group.dayLabel) {
                                ForEach(group.memories) { memory in
                                    NavigationLink {
                                        MemoryDetailView(recordID: memory.id)
                                            .moryHidesTabChrome()
                                    } label: {
                                        TimelineMemoryRow(memory: memory)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("timeline.nav.title")
        .moryHidesTabChrome()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("timeline.memoryCount \(timeline?.totalCount ?? 0)")
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: selectedGranularity) { _, _ in
            loadTimeline()
        }
        .task {
            loadTimeline()
        }
    }

    private func loadTimeline() {
        do {
            timeline = try memoryRepository.fetchTimeline(granularity: selectedGranularity, limit: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct TimelineMemoryRow: View {
    let memory: MemorySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(memory.title)
                .font(.headline)
                .lineLimit(1)

            Text(memory.summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                if memory.artifactCount > 0 {
                    Label {
                        Text(verbatim: "\(memory.artifactCount)")
                    } icon: {
                        Image(systemName: "paperclip")
                    }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let status = memory.pipelineStatus {
                    PipelineStatusBadge(status: status)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PipelineStatusBadge: View {
    let status: MemoryPipelineStatusSnapshot

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(status.userLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch status.stage {
        case .notScheduled: return .secondary
        case .pending: return .gray
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}
