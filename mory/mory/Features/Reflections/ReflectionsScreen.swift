import SwiftUI

struct ReflectionsScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var reflections: [ReflectionSnapshot] = []
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("Reflections") {
                if reflections.isEmpty {
                    Text("Reflection objects will appear here once analysis and arc reflection are connected.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(reflections) { reflection in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(reflection.title)
                                    .font(.headline)
                                Spacer()
                                Text(reflection.status.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(reflection.body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                            Text(reflection.evidenceSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Reflections")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        do {
            reflections = try memoryRepository.fetchReflections(limit: 20)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
