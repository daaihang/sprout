import SwiftUI

struct ArcsScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var arcs: [TemporalArc] = []
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("Arcs") {
                if arcs.isEmpty {
                    Text("Temporal arcs will appear here once phase-layer accumulation is connected.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(arcs) { arc in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(arc.title)
                                    .font(.headline)
                                Spacer()
                                Text(arc.status.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(arc.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                            Text("\(arc.startDate.formatted(date: .abbreviated, time: .omitted)) - \(arc.endDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Arcs")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        do {
            arcs = try memoryRepository.fetchTemporalArcs(limit: 20)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
