import SwiftUI
import SwiftData

struct SearchHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let selectedDate: Date

    @State private var query = ""

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: SproutMemoryRepository.SearchResults {
        memoryRepository.searchResults(matching: trimmedQuery)
    }

    private var featuredPeople: [SproutMemoryRepository.PersonIndexEntry] {
        memoryRepository.peopleIndex(limit: 4)
    }

    private var featuredThemes: [EntityNode] {
        memoryRepository.entityNodes
            .filter { $0.kind == .theme }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(4)
            .map { $0 }
    }

    private var featuredArcs: [TemporalArc] {
        memoryRepository.temporalArcs
            .filter { $0.status == .accepted }
            .sorted {
                if $0.endDate == $1.endDate {
                    return $0.intensityScore > $1.intensityScore
                }
                return $0.endDate > $1.endDate
            }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if trimmedQuery.isEmpty {
                    browseState
                } else {
                    resultsState
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .padding(.bottom, 40)
        }
        .background(Color.clear)
        .searchable(text: $query, prompt: "Search people, themes, places, phases")
    }

    private var browseState: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Search")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Search across people, phases, memories, and artifacts from the same memory graph.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !featuredPeople.isEmpty {
                browseSection(title: "People", subtitle: "Start from long-term relationships") {
                    ForEach(featuredPeople, id: \.id) { person in
                        NavigationLink {
                            MemoryEntityDetailView(entityID: person.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(person.entity.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("\(person.relatedRecordCount) memories · \(person.arcTitles.first ?? person.placeNames.first ?? "Person graph")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !featuredThemes.isEmpty {
                browseSection(title: "Themes", subtitle: "Jump into recurring topics") {
                    chipCloud(featuredThemes.map(\.displayName), tint: .orange)
                }
            }

            if !featuredArcs.isEmpty {
                browseSection(title: "Phases", subtitle: "Search by longer arcs, not only single records") {
                    ForEach(featuredArcs, id: \.id) { arc in
                        NavigationLink {
                            TemporalArcDetailView(arc: arc)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(arc.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(arc.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var resultsState: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isEmpty(results) {
                HomeSectionPlaceholderView(
                    systemImage: "magnifyingglass",
                    title: "No Results",
                    subtitle: "Try a person, place, theme, phase title, or a line from a memory."
                )
            } else {
                if !results.entities.isEmpty {
                    browseSection(title: "Entities", subtitle: "People, places, themes, decisions") {
                        ForEach(results.entities, id: \.id) { entity in
                            NavigationLink {
                                MemoryEntityDetailView(entityID: entity.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Text(entity.kind.badgeLabel)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(entity.kind.tintColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(entity.kind.tintColor.opacity(0.12), in: Capsule())

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entity.displayName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        if !entity.summary.isEmpty {
                                            Text(entity.summary)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !results.arcs.isEmpty {
                    browseSection(title: "Phases", subtitle: "Temporal arcs and stage summaries") {
                        ForEach(results.arcs, id: \.id) { arc in
                            NavigationLink {
                                TemporalArcDetailView(arc: arc)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(arc.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(arc.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    Text(dateRangeText(for: arc))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !results.records.isEmpty {
                    browseSection(title: "Memories", subtitle: "Raw capture shells and analyzed records") {
                        ForEach(results.records, id: \.id) { record in
                            if let fullRecord = fetchRecord(id: record.id) {
                                NavigationLink {
                                    RecordDetailView(record: fullRecord)
                                } label: {
                                    recordRow(record)
                                }
                                .buttonStyle(.plain)
                            } else {
                                recordRow(record)
                            }
                        }
                    }
                }

                if !results.artifacts.isEmpty {
                    browseSection(title: "Artifacts", subtitle: "Text, media, and referenced fragments") {
                        ForEach(results.artifacts, id: \.id) { artifact in
                            artifactRow(artifact)
                        }
                    }
                }
            }
        }
    }

    private func browseSection<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }

    private func chipCloud(_ values: [String], tint: Color) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Button {
                        query = value
                    } label: {
                        Text(value)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(tint.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func recordRow(_ record: RecordShell) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.rawText.isEmpty ? "Untitled Memory" : String(record.rawText.prefix(120)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(3)
            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func artifactRow(_ artifact: Artifact) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(artifact.kind.rawValue.capitalized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.12), in: Capsule())
                Text(artifact.title.isEmpty ? "Untitled Artifact" : artifact.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            if !artifact.summary.isEmpty {
                Text(artifact.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if !artifact.textContent.isEmpty {
                Text(String(artifact.textContent.prefix(140)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func dateRangeText(for arc: TemporalArc) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: arc.startDate, to: arc.endDate)
    }

    private func fetchRecord(id: UUID) -> Record? {
        let records = (try? modelContext.fetch(FetchDescriptor<Record>())) ?? []
        return records.first { $0.id == id }
    }

    private func isEmpty(_ results: SproutMemoryRepository.SearchResults) -> Bool {
        results.entities.isEmpty
            && results.arcs.isEmpty
            && results.records.isEmpty
            && results.artifacts.isEmpty
    }
}
