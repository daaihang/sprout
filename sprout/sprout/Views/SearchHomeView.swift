import SwiftUI
import SwiftData

struct SearchHomeView: View {
    private enum SearchTimeRange: String, CaseIterable, Identifiable {
        case allTime
        case last7Days
        case last30Days
        case last90Days
        case last365Days

        var id: String { rawValue }

        var title: String {
            switch self {
            case .allTime: return "Any Time"
            case .last7Days: return "7d"
            case .last30Days: return "30d"
            case .last90Days: return "90d"
            case .last365Days: return "1y"
            }
        }

        var days: Int {
            switch self {
            case .allTime: return 3650
            case .last7Days: return 7
            case .last30Days: return 30
            case .last90Days: return 90
            case .last365Days: return 365
            }
        }
    }

    private enum PhaseLifecycleFilter: String, CaseIterable, Identifiable {
        case all
        case active
        case archived
        case savedReflection
        case dismissedReflection

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All Phases"
            case .active: return "Active"
            case .archived: return "Archived"
            case .savedReflection: return "Saved Reflection"
            case .dismissedReflection: return "Dismissed Reflection"
            }
        }
    }

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
    @State private var selectedTimeRange: SearchTimeRange = .allTime
    @State private var selectedEmotionLabel: String = "All"
    @State private var selectedPhaseLifecycle: PhaseLifecycleFilter = .all
    @AppStorage("searchRecentQueries") private var recentSearchQueriesStorage = "[]"

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

    private var featuredEmotions: [(label: String, count: Int)] {
        let labels = memoryRepository.analyses.map(\.emotionLabel)
            + memoryRepository.recordShells.compactMap(\.userMood)
        let counts = Dictionary(grouping: labels.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { $0 }
            .mapValues(\.count)
        return counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
                }
                return lhs.value > rhs.value
            }
            .prefix(5)
            .map { (label: $0.key, count: $0.value) }
    }

    private var featuredReflections: [ReflectionSnapshot] {
        memoryRepository.reflections
            .filter(matchesPhaseLifecycle)
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(4)
            .map { $0 }
    }

    private var recentQueries: [String] {
        decodeRecentQueries(from: recentSearchQueriesStorage)
    }

    private var featuredArcs: [TemporalArc] {
        memoryRepository.temporalArcs
            .filter(matchesPhaseLifecycle)
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
            guard matchesTimeRange(entity: entity) else { return false }
            guard matchesEmotion(entity: entity) else { return false }
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
        (selectedCategory == .all || selectedCategory == .phases ? results.arcs : [])
            .filter { matchesTimeRange(arc: $0) && matchesEmotion(arc: $0) && matchesPhaseLifecycle($0) }
    }

    private var filteredRecords: [RecordShell] {
        (selectedCategory == .all || selectedCategory == .memories ? results.records : [])
            .filter { matchesTimeRange(record: $0) && matchesEmotion(record: $0) }
    }

    private var filteredArtifacts: [Artifact] {
        (selectedCategory == .all || selectedCategory == .artifacts ? results.artifacts : [])
            .filter { matchesTimeRange(artifact: $0) && matchesEmotion(artifact: $0) }
    }

    private var filteredReflections: [ReflectionSnapshot] {
        (selectedCategory == .all || selectedCategory == .phases ? results.reflections : [])
            .filter { matchesTimeRange(reflection: $0) && matchesPhaseLifecycle($0) }
    }

    private var totalFilteredCount: Int {
        filteredEntities.count + filteredArcs.count + filteredRecords.count + filteredArtifacts.count + filteredReflections.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                categoryStrip
                filterStrip
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
        .onSubmit(of: .search) {
            commitSearch()
        }
    }

    private var browseState: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Search")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Search across people, phases, memories, and artifacts from the same memory graph.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !recentQueries.isEmpty {
                browseSection(title: "Recent", subtitle: "Jump back to recent queries") {
                    chipCloud(recentQueries, tint: .secondary)
                }
            }

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

            if selectedCategory == .all || selectedCategory == .memories, !featuredEmotions.isEmpty {
                browseSection(title: "Emotions", subtitle: "Jump into the dominant feelings in memory") {
                    chipCloud(featuredEmotions.map(\.label), tint: .purple)
                }
            }

            if selectedCategory == .all || selectedCategory == .phases, !featuredArcs.isEmpty {
                browseSection(title: "Phases", subtitle: "Search by longer arcs, not only single records") {
                    ForEach(featuredArcs, id: \.id) { arc in
                        NavigationLink {
                            TemporalArcDetailView(arc: arc)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(arc.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    phaseLifecyclePill(for: arc)
                                }
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

            if selectedCategory == .all || selectedCategory == .phases, !featuredReflections.isEmpty {
                browseSection(title: "Reflections", subtitle: "Keep, dismiss, or reopen meaning snapshots") {
                    ForEach(featuredReflections, id: \.id) { reflection in
                        NavigationLink {
                            ReflectionDetailView(reflection: reflection)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(reflection.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    reflectionStatusPill(reflection)
                                }
                                Text(reflection.body)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                if let evidenceSummary = reflection.evidenceSummary {
                                    Text(evidenceSummary)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary.opacity(0.85))
                                        .lineLimit(1)
                                }
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
                                let entityView = memoryRepository.entityView(for: entity.id)
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
                                        } else if let entityView {
                                            Text(entityEvidenceSummary(for: entity, view: entityView))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }

                                        if let entityView, !entityView.relatedEntities.isEmpty {
                                            Text(
                                                entityView.relatedEntities
                                                    .prefix(3)
                                                    .map(\.displayName)
                                                    .joined(separator: " · ")
                                            )
                                            .font(.caption2)
                                            .foregroundStyle(.secondary.opacity(0.85))
                                            .lineLimit(1)
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
                                let evidenceView = memoryRepository.arcEvidenceView(for: arc.id)
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Text(arc.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        phaseLifecyclePill(for: arc)
                                    }
                                    Text(arc.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    if let reflection = evidenceView?.linkedReflection {
                                        HStack(spacing: 6) {
                                            Text(reflection.title)
                                                .font(.caption)
                                                .foregroundStyle(.secondary.opacity(0.9))
                                                .lineLimit(1)
                                            reflectionStatusPill(reflection)
                                        }
                                    }
                                    if let evidenceView {
                                        Text(arcEvidenceSummary(for: evidenceView))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary.opacity(0.8))
                                            .lineLimit(1)
                                    }
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
                            NavigationLink {
                                ArtifactDetailView(artifact: artifact)
                            } label: {
                                let evidenceView = memoryRepository.artifactEvidenceView(for: artifact.id)
                                VStack(alignment: .leading, spacing: 8) {
                                    ArtifactRowView(
                                        artifact: artifact,
                                        entityNames: evidenceView?.linkedEntities.map(\.displayName) ?? [],
                                        style: .card
                                    )

                                    if let evidenceView {
                                        if let firstAnalysis = evidenceView.relatedAnalyses.first {
                                            Text("\(firstAnalysis.emotionLabel.capitalized) · \(firstAnalysis.insight)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }

                                        Text(artifactEvidenceSummary(for: evidenceView))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary.opacity(0.85))
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !filteredReflections.isEmpty {
                    browseSection(title: "Reflections", subtitle: "Meaning snapshots with lifecycle state") {
                        ForEach(filteredReflections, id: \.id) { reflection in
                            NavigationLink {
                                ReflectionDetailView(reflection: reflection)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Text(reflection.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        reflectionStatusPill(reflection)
                                    }
                                    Text(reflection.body)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                    Text(reflection.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary.opacity(0.85))
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

    private var filterStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SearchTimeRange.allCases) { range in
                        filterChip(
                            title: range.title,
                            isSelected: selectedTimeRange == range
                        ) {
                            selectedTimeRange = range
                        }
                    }
                }
            }

            if !featuredEmotions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(
                            title: "All Emotions",
                            isSelected: selectedEmotionLabel == "All"
                        ) {
                            selectedEmotionLabel = "All"
                        }

                        ForEach(featuredEmotions, id: \.label) { item in
                            filterChip(
                                title: item.label,
                                isSelected: selectedEmotionLabel == item.label
                            ) {
                                selectedEmotionLabel = item.label
                            }
                        }
                    }
                }
            }

            if selectedCategory == .all || selectedCategory == .phases {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PhaseLifecycleFilter.allCases) { filter in
                            filterChip(
                                title: filter.title,
                                isSelected: selectedPhaseLifecycle == filter
                            ) {
                                selectedPhaseLifecycle = filter
                            }
                        }
                    }
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
                        commitSearch()
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

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor : Color.white.opacity(0.16))
                )
        }
        .buttonStyle(.plain)
    }

    private func recordRow(_ record: RecordShell) -> some View {
        let analysis = memoryRepository.analysis(for: record.id)
        return VStack(alignment: .leading, spacing: 6) {
            Text(record.rawText.isEmpty ? "Untitled Memory" : String(record.rawText.prefix(120)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(3)

            if let analysis {
                AnalysisCompactEvidenceView(
                    analysis: analysis,
                    showInsight: true,
                    showEntities: true,
                    showRetrievalTerms: true,
                    showReflectionHint: false,
                    maxEntityCount: 3,
                    maxRetrievalTermCount: 4
                )
            }

            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func entityEvidenceSummary(
        for entity: EntityNode,
        view: SproutMemoryRepository.EntityMemoryView
    ) -> String {
        let parts = [
            "\(view.relatedRecords.count) memories",
            view.relatedArtifacts.isEmpty ? nil : "\(view.relatedArtifacts.count) artifacts",
            view.relatedEntities.isEmpty ? nil : "\(view.relatedEntities.count) links"
        ].compactMap { $0 }

        if !parts.isEmpty {
            return parts.joined(separator: " · ")
        }

        return entity.kind.badgeLabel
    }

    private func artifactEvidenceSummary(for evidenceView: SproutMemoryRepository.ArtifactEvidenceView) -> String {
        let parts = [
            evidenceView.relatedRecordShells.isEmpty ? nil : "\(evidenceView.relatedRecordShells.count) memories",
            evidenceView.linkedEntities.isEmpty ? nil : "\(evidenceView.linkedEntities.count) entities",
            evidenceView.relatedArcs.isEmpty ? nil : "\(evidenceView.relatedArcs.count) phases"
        ].compactMap { $0 }

        return parts.isEmpty ? "No linked evidence yet" : parts.joined(separator: " · ")
    }

    private func arcEvidenceSummary(for evidenceView: SproutMemoryRepository.ArcEvidenceView) -> String {
        let parts = [
            evidenceView.relatedRecordShells.isEmpty ? nil : "\(evidenceView.relatedRecordShells.count) memories",
            evidenceView.relatedAnalyses.isEmpty ? nil : "\(evidenceView.relatedAnalyses.count) analyses",
            evidenceView.linkedEntities.isEmpty ? nil : "\(evidenceView.linkedEntities.count) entities"
        ].compactMap { $0 }

        return parts.isEmpty ? "No linked evidence yet" : parts.joined(separator: " · ")
    }

    private func matchesPhaseLifecycle(_ reflection: ReflectionSnapshot) -> Bool {
        switch selectedPhaseLifecycle {
        case .all:
            return true
        case .active:
            return reflection.status == .active
        case .archived:
            return false
        case .savedReflection:
            return reflection.status == .saved
        case .dismissedReflection:
            return reflection.status == .dismissed
        }
    }

    private func matchesTimeRange(reflection: ReflectionSnapshot) -> Bool {
        switch selectedTimeRange {
        case .allTime: return true
        case .last7Days: return reflection.createdAt >= dateThreshold(days: 7)
        case .last30Days: return reflection.createdAt >= dateThreshold(days: 30)
        case .last90Days: return reflection.createdAt >= dateThreshold(days: 90)
        case .last365Days: return reflection.createdAt >= dateThreshold(days: 365)
        }
    }

    private func matchesPhaseLifecycle(_ arc: TemporalArc) -> Bool {
        let reflection = memoryRepository.linkedReflection(forArcID: arc.id)

        switch selectedPhaseLifecycle {
        case .all:
            return true
        case .active:
            return arc.status == .accepted
        case .archived:
            return arc.status == .archived
        case .savedReflection:
            return reflection?.status == .saved
        case .dismissedReflection:
            return reflection?.status == .dismissed
        }
    }

    private func reflectionStatusPill(_ reflection: ReflectionSnapshot) -> some View {
        SignalPill(title: reflection.statusDisplayText, tint: reflectionStatusTint(reflection.status))
    }

    @ViewBuilder
    private func phaseLifecyclePill(for arc: TemporalArc) -> some View {
        switch arc.status {
        case .accepted:
            SignalPill(title: "Active", tint: .orange)
        case .archived:
            SignalPill(title: "Archived", tint: .secondary)
        case .candidate:
            SignalPill(title: "Candidate", tint: .purple)
        }
    }

    private func reflectionStatusTint(_ status: ReflectionStatus) -> Color {
        switch status {
        case .active:
            return .blue
        case .saved:
            return .green
        case .dismissed:
            return .secondary
        }
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

    private func commitSearch() {
        let value = trimmedQuery
        guard !value.isEmpty else { return }
        addRecentQuery(value)
    }

    private func addRecentQuery(_ query: String) {
        var queries = decodeRecentQueries(from: recentSearchQueriesStorage)
        queries.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        queries.insert(query, at: 0)
        recentSearchQueriesStorage = encodeRecentQueries(queries.prefix(6).map { $0 })
    }

    private func decodeRecentQueries(from storage: String) -> [String] {
        guard let data = storage.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return values
    }

    private func encodeRecentQueries(_ queries: [String]) -> String {
        guard let data = try? JSONEncoder().encode(Array(queries)) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    private func matchesTimeRange(record: RecordShell) -> Bool {
        switch selectedTimeRange {
        case .allTime: return true
        case .last7Days: return record.createdAt >= dateThreshold(days: 7)
        case .last30Days: return record.createdAt >= dateThreshold(days: 30)
        case .last90Days: return record.createdAt >= dateThreshold(days: 90)
        case .last365Days: return record.createdAt >= dateThreshold(days: 365)
        }
    }

    private func matchesTimeRange(arc: TemporalArc) -> Bool {
        switch selectedTimeRange {
        case .allTime: return true
        case .last7Days:
            return arc.endDate >= dateThreshold(days: 7)
        case .last30Days:
            return arc.endDate >= dateThreshold(days: 30)
        case .last90Days:
            return arc.endDate >= dateThreshold(days: 90)
        case .last365Days:
            return arc.endDate >= dateThreshold(days: 365)
        }
    }

    private func matchesTimeRange(entity: EntityNode) -> Bool {
        guard selectedTimeRange != .allTime else { return true }
        guard let view = memoryRepository.entityView(for: entity.id) else { return false }
        let latestDate = view.relatedRecords.map(\.createdAt).max() ?? entity.updatedAt
        return latestDate >= dateThreshold(days: selectedTimeRange.days)
    }

    private func matchesTimeRange(artifact: Artifact) -> Bool {
        switch selectedTimeRange {
        case .allTime: return true
        case .last7Days: return artifact.createdAt >= dateThreshold(days: 7)
        case .last30Days: return artifact.createdAt >= dateThreshold(days: 30)
        case .last90Days: return artifact.createdAt >= dateThreshold(days: 90)
        case .last365Days: return artifact.createdAt >= dateThreshold(days: 365)
        }
    }

    private func matchesEmotion(record: RecordShell) -> Bool {
        guard selectedEmotionLabel != "All" else { return true }
        let labels = emotionLabels(for: record)
        return labels.contains { $0.caseInsensitiveCompare(selectedEmotionLabel) == .orderedSame }
    }

    private func matchesEmotion(arc: TemporalArc) -> Bool {
        guard selectedEmotionLabel != "All" else { return true }
        let labels = emotionLabels(for: arc)
        return labels.contains { $0.caseInsensitiveCompare(selectedEmotionLabel) == .orderedSame }
    }

    private func matchesEmotion(entity: EntityNode) -> Bool {
        guard selectedEmotionLabel != "All" else { return true }
        guard let view = memoryRepository.entityView(for: entity.id) else { return false }
        let labels = view.relatedRecords.flatMap(emotionLabels(for:))
        return labels.contains { $0.caseInsensitiveCompare(selectedEmotionLabel) == .orderedSame }
    }

    private func matchesEmotion(artifact: Artifact) -> Bool {
        guard selectedEmotionLabel != "All" else { return true }
        let linkedEntityIDs = Set(
            memoryRepository.artifactEntityLinks
                .filter { $0.artifactID == artifact.id }
                .map(\.entityID)
        )
        let labels = linkedEntityIDs.compactMap(memoryRepository.entityNode(for:)).flatMap { entity -> [String] in
            guard let view = memoryRepository.entityView(for: entity.id) else { return [] }
            return view.relatedRecords.flatMap(emotionLabels(for:))
        }
        return labels.contains { $0.caseInsensitiveCompare(selectedEmotionLabel) == .orderedSame }
    }

    private func emotionLabels(for record: RecordShell) -> [String] {
        var labels: [String] = []
        if let mood = record.userMood, !mood.isEmpty {
            labels.append(mood)
        }
        if let analysis = memoryRepository.analysis(for: record.id) {
            labels.append(analysis.emotionLabel)
        }
        return labels
    }

    private func emotionLabels(for arc: TemporalArc) -> [String] {
        arc.sourceRecordIDs.flatMap { recordID in
            guard let shell = memoryRepository.recordShell(for: recordID) else { return [String]() }
            return emotionLabels(for: shell)
        }
    }

    private func dateThreshold(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
}
