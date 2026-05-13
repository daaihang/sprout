import SwiftUI
import SwiftData

struct SearchHomeView: View {
    private enum SearchCategory: String, CaseIterable, Identifiable {
        case all
        case people
        case places
        case themes
        case decisions
        case phases
        case memories
        case artifacts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All"
            case .people: return "People"
            case .places: return "Places"
            case .themes: return "Themes"
            case .decisions: return "Decisions"
            case .phases: return "Phases"
            case .memories: return "Memories"
            case .artifacts: return "Artifacts"
            }
        }

        var systemImage: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .people: return "person.2"
            case .places: return "map"
            case .themes: return "tag"
            case .decisions: return "checkmark.circle"
            case .phases: return "timeline.selection"
            case .memories: return "list.bullet.rectangle"
            case .artifacts: return "shippingbox"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let selectedDate: Date

    @State private var query = ""
    @State private var selectedCategory: SearchCategory = .all

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

    private var featuredPlaces: [EntityNode] {
        memoryRepository.entityNodes
            .filter { $0.kind == .place }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(4)
            .map { $0 }
    }

    private var featuredDecisions: [EntityNode] {
        memoryRepository.entityNodes
            .filter { $0.kind == .decision }
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

    private var filteredEntities: [EntityNode] {
        filtered(results.entities, matching: { entity in
            switch selectedCategory {
            case .all:
                return true
            case .people:
                return entity.kind == .person
            case .places:
                return entity.kind == .place
            case .themes:
                return entity.kind == .theme
            case .decisions:
                return entity.kind == .decision
            case .phases, .memories, .artifacts:
                return false
            }
        })
    }

    private var filteredArcs: [TemporalArc] {
        selectedCategory == .all || selectedCategory == .phases ? results.arcs : []
    }

    private var filteredRecords: [RecordShell] {
        selectedCategory == .all || selectedCategory == .memories ? results.records : []
    }

    private var filteredArtifacts: [Artifact] {
        selectedCategory == .all || selectedCategory == .artifacts ? results.artifacts : []
    }

    private var totalFilteredCount: Int {
        filteredEntities.count + filteredArcs.count + filteredRecords.count + filteredArtifacts.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                categoryStrip
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

            if selectedCategory == .all || selectedCategory == .people, !featuredPeople.isEmpty {
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

            if selectedCategory == .all || selectedCategory == .themes, !featuredThemes.isEmpty {
                browseSection(title: "Themes", subtitle: "Jump into recurring topics") {
                    chipCloud(featuredThemes.map(\.displayName), tint: .orange)
                }
            }

            if selectedCategory == .all || selectedCategory == .places, !featuredPlaces.isEmpty {
                browseSection(title: "Places", subtitle: "Ground search in location memory") {
                    chipCloud(featuredPlaces.map(\.displayName), tint: .green)
                }
            }

            if selectedCategory == .all || selectedCategory == .decisions, !featuredDecisions.isEmpty {
                browseSection(title: "Decisions", subtitle: "Jump to important choice markers") {
                    chipCloud(featuredDecisions.map(\.displayName), tint: .pink)
                }
            }

            if selectedCategory == .all || selectedCategory == .phases, !featuredArcs.isEmpty {
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
            Text("\(totalFilteredCount) matches")
                .font(.headline)
                .foregroundStyle(.secondary)

            if totalFilteredCount == 0 {
                HomeSectionPlaceholderView(
                    systemImage: "magnifyingglass",
                    title: "No Results",
                    subtitle: "Try a person, place, theme, phase title, or a line from a memory."
                )
            } else {
                if !filteredEntities.isEmpty {
                    browseSection(title: "Entities", subtitle: "People, places, themes, decisions") {
                        ForEach(filteredEntities, id: \.id) { entity in
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

                if !filteredArcs.isEmpty {
                    browseSection(title: "Phases", subtitle: "Temporal arcs and stage summaries") {
                        ForEach(filteredArcs, id: \.id) { arc in
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

                if !filteredRecords.isEmpty {
                    browseSection(title: "Memories", subtitle: "Raw capture shells and analyzed records") {
                        ForEach(filteredRecords, id: \.id) { record in
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

                if !filteredArtifacts.isEmpty {
                    browseSection(title: "Artifacts", subtitle: "Text, media, and referenced fragments") {
                        ForEach(filteredArtifacts, id: \.id) { artifact in
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

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SearchCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Label(category.title, systemImage: category.systemImage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedCategory == category ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(selectedCategory == category ? Color.accentColor : Color.white.opacity(0.16))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
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

    private func filtered<T>(_ items: [T], matching predicate: (T) -> Bool) -> [T] {
        items.filter(predicate)
    }
}
