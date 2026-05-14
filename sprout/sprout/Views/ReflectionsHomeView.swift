import SwiftUI
import SwiftData

struct ReflectionsHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    @State private var selectedSort: SortOption = .recent

    enum SortOption: String, CaseIterable {
        case recent, oldest, confidence

        var label: String {
            switch self {
            case .recent: return "Recent"
            case .oldest: return "Oldest"
            case .confidence: return "Confidence"
            }
        }
    }

    private var sortedReflections: [ReflectionSnapshot] {
        let reflections = memoryRepository.reflections

        switch selectedSort {
        case .recent:
            return reflections.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return reflections.sorted { $0.createdAt < $1.createdAt }
        case .confidence:
            return reflections.sorted { 
                let conf1 = $0.confidencePercentage ?? 0
                let conf2 = $1.confidencePercentage ?? 0
                return conf1 > conf2
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reflections")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(sortedReflections.count) total meaning snapshots")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Picker("Sort by", selection: $selectedSort) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 8)

                if sortedReflections.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary.opacity(0.4))

                        VStack(spacing: 6) {
                            Text("No reflections yet")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Create your first reflection from a record or phase detail.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    VStack(spacing: 12) {
                        ForEach(sortedReflections, id: \.id) { reflection in
                            NavigationLink {
                                ReflectionDetailView(reflection: reflection)
                            } label: {
                                reflectionRow(reflection)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .padding(.bottom, 40)
        }
    }

    private func reflectionRow(_ reflection: ReflectionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(reflection.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let confidence = reflection.confidencePercentage {
                    Text("\(Int(confidence))%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                }

                Spacer()

                Text(reflection.statusDisplayText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }

            Text(reflection.body)
                .font(.caption)
                .lineLimit(3)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if let arcID = reflection.linkedTemporalArcID,
                   let arc = memoryRepository.temporalArc(for: arcID) {
                    Label(arc.title, systemImage: "timeline.selection")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Text(reflection.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    ReflectionsHomeView()
        .environment(SproutMemoryRepository())
}
