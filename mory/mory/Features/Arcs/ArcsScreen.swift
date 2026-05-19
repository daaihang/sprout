import SwiftUI

struct ArcsScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var arcs: [TemporalArcSummarySnapshot] = []
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("arcs.section.title") {
                if arcs.isEmpty {
                    Text("arcs.empty.description")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(arcs) { item in
                        NavigationLink {
                            ArcDetailView(arcID: item.arc.id)
                                .moryHidesTabChrome()
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.arc.title)
                                        .font(.headline)
                                    Spacer()
                                    Text(item.arc.status.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(item.arc.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                Text(verbatim: "\(item.arc.startDate.formatted(date: .abbreviated, time: .omitted)) - \(item.arc.endDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !item.relatedMemories.isEmpty {
                                    Text(item.relatedMemories.map(\.title).joined(separator: " | "))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                if let reflection = item.linkedReflection {
                                    Text(reflection.title)
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("arcs.nav.title")
        .moryHidesTabChrome()
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        do {
            arcs = try memoryRepository.fetchTemporalArcSummaries(limit: 20)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
