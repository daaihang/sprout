import SwiftUI

struct ReflectionInboxView: View {
    private enum InboxFilter: String, CaseIterable, Identifiable {
        case all
        case active
        case saved
        case dismissed
        case phase
        case record

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All"
            case .active: return "Active"
            case .saved: return "Saved"
            case .dismissed: return "Dismissed"
            case .phase: return "Phase"
            case .record: return "Record"
            }
        }
    }

    @Environment(AppLocalization.self) private var localization
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    @State private var query = ""
    @State private var selectedFilter: InboxFilter = .all

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var allReflections: [ReflectionSnapshot] {
        memoryRepository.reflections
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.createdAt > $1.createdAt
            }
    }

    private var filteredReflections: [ReflectionSnapshot] {
        allReflections.filter { reflection in
            matchesFilter(reflection) && matchesQuery(reflection)
        }
    }

    private var activeCount: Int {
        memoryRepository.reflections.filter { $0.status == .active }.count
    }

    private var savedCount: Int {
        memoryRepository.reflections.filter { $0.status == .saved }.count
    }

    private var dismissedCount: Int {
        memoryRepository.reflections.filter { $0.status == .dismissed }.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                filterStrip
                summaryStrip
                inboxList
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .padding(.bottom, 40)
        }
        .background(Color.clear)
        .navigationTitle(localization.string("common.reflection_inbox", default: "Reflection Inbox"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: localization.string("content.search_prompt", default: "Search reflections"))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reflection Inbox")
                .font(.largeTitle.weight(.semibold))
            Text(localization.string("content.reflection_inbox_subtitle", default: "Save what matters, dismiss what doesn't, and keep phase reflections visible as your memory system grows."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .detailCard()
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InboxFilter.allCases) { filter in
                    filterChip(title: filter.title, isSelected: selectedFilter == filter) {
                        selectedFilter = filter
                    }
                }
            }
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 8) {
            SignalPill(title: "\(activeCount) active", tint: .blue)
            SignalPill(title: "\(savedCount) saved", tint: .green)
            SignalPill(title: "\(dismissedCount) dismissed", tint: .secondary)
        }
    }

    private var inboxList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if filteredReflections.isEmpty {
                HomeSectionPlaceholderView(
                    systemImage: "tray",
                    title: "No Reflections",
                    subtitle: "Try another filter or add more captures to let the inbox grow."
                )
            } else {
                ForEach(filteredReflections, id: \.id) { reflection in
                    reflectionCard(reflection)
                }
            }
        }
    }

    private func reflectionCard(_ reflection: ReflectionSnapshot) -> some View {
        let linkedArc = reflection.linkedTemporalArcID.flatMap(memoryRepository.temporalArc(for:))

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(reflection.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        SignalPill(title: reflection.statusDisplayText, tint: statusTint(reflection.status))
                        if reflection.type == .phase {
                            SignalPill(title: "Phase", tint: .orange)
                        }
                    }

                    Text(reflection.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }

                Spacer()

                NavigationLink {
                    ReflectionDetailView(reflection: reflection)
                } label: {
                    Image(systemName: "arrow.right.circle")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                if let linkedArc {
                    NavigationLink {
                        TemporalArcDetailView(arc: linkedArc)
                    } label: {
                        SignalPill(title: linkedArc.title, tint: .orange)
                    }
                    .buttonStyle(.plain)
                }

                SignalPill(title: "\(reflection.sourceRecordIDs.count) memories", tint: .blue)
                if !reflection.sourceEntityIDs.isEmpty {
                    SignalPill(title: "\(reflection.sourceEntityIDs.count) entities", tint: .green)
                }
            }

            if let evidenceSummary = reflection.evidenceSummary, !evidenceSummary.isEmpty {
                EvidenceCalloutCard(title: "Evidence", bodyText: evidenceSummary)
            }

            actionRow(for: reflection)
        }
        .detailCard()
    }

    private func actionRow(for reflection: ReflectionSnapshot) -> some View {
        HStack(spacing: 10) {
            if reflection.status != .saved {
                Button("Save") {
                    memoryRepository.saveReflection(reflection.id)
                }
                .buttonStyle(.borderedProminent)
            }

            if reflection.status != .dismissed {
                Button("Dismiss") {
                    memoryRepository.dismissReflection(reflection.id)
                }
                .buttonStyle(.bordered)
            }

            if reflection.status == .dismissed {
                Button("Reactivate") {
                    memoryRepository.reactivateReflection(reflection.id)
                }
                .buttonStyle(.bordered)
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
                .background(Capsule().fill(isSelected ? Color.accentColor : Color.white.opacity(0.16)))
        }
        .buttonStyle(.plain)
    }

    private func matchesFilter(_ reflection: ReflectionSnapshot) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .active:
            return reflection.status == .active
        case .saved:
            return reflection.status == .saved
        case .dismissed:
            return reflection.status == .dismissed
        case .phase:
            return reflection.type == .phase
        case .record:
            return reflection.type == .record
        }
    }

    private func matchesQuery(_ reflection: ReflectionSnapshot) -> Bool {
        guard !trimmedQuery.isEmpty else { return true }
        let fields = [
            reflection.title,
            reflection.body,
            reflection.evidenceSummary ?? "",
            reflection.type.rawValue,
            reflection.status.rawValue
        ]
        let query = trimmedQuery.lowercased()
        return fields.contains { $0.lowercased().contains(query) }
    }

    private func statusTint(_ status: ReflectionStatus) -> Color {
        switch status {
        case .active:
            return .blue
        case .saved:
            return .green
        case .dismissed:
            return .secondary
        }
    }
}

#Preview {
    NavigationStack {
        ReflectionInboxView()
    }
}
