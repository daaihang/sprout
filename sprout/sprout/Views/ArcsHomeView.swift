import SwiftUI

struct ArcsHomeView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(SproutMemoryRepository.self) private var memoryRepository
    let selectedDate: Date

    private var acceptedArcs: [TemporalArc] {
        memoryRepository.temporalArcs
            .filter { $0.status == .accepted }
            .sorted {
                if $0.endDate == $1.endDate {
                    return $0.intensityScore > $1.intensityScore
                }
                return $0.endDate > $1.endDate
            }
    }

    private var archivedArcs: [TemporalArc] {
        memoryRepository.temporalArcs
            .filter { $0.status == .archived }
            .sorted {
                if $0.updatedAt == $1.updatedAt {
                    return $0.endDate > $1.endDate
                }
                return $0.updatedAt > $1.updatedAt
            }
    }

    private var featuredArc: TemporalArc? {
        memoryRepository.featuredTemporalArc(for: selectedDate)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if let featuredArc {
                    featuredSection(featuredArc)
                }
                if !acceptedArcs.isEmpty {
                    activeArcListSection
                }
                if !archivedArcs.isEmpty {
                    archivedArcListSection
                } else {
                    if acceptedArcs.isEmpty {
                        emptyState
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .padding(.bottom, 40)
        }
        .background(Color.clear)
    }

    private func featuredSection(_ arc: TemporalArc) -> some View {
        let evidenceView = memoryRepository.arcEvidenceView(for: arc.id)
        return VStack(alignment: .leading, spacing: 12) {
            Text(localization.string("common.current_phase", default: "Current Phase"))
                .font(.headline)

            NavigationLink {
                TemporalArcDetailView(arc: arc)
            } label: {
                TemporalArcCard(data: TemporalArcCardData(
                    title: arc.title,
                    summary: arc.summary,
                    dominantTheme: arc.dominantTheme,
                    dominantEntityName: arc.dominantEntityName,
                    dateRangeText: dateRangeText(for: arc),
                    recordCount: arc.sourceRecordIDs.count,
                    artifactCount: arc.sourceArtifactIDs.count
                ))
                .frame(height: 220)
            }
            .buttonStyle(.plain)

            if let evidenceView {
                Text(arcEvidenceSummary(for: evidenceView))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let reflection = memoryRepository.linkedReflection(forArcID: arc.id) {
                NavigationLink {
                    ReflectionDetailView(reflection: reflection)
                } label: {
                    PhaseReflectionCard(data: PhaseReflectionCardData(
                        title: reflection.title,
                        body: reflection.body,
                        phaseTitle: arc.title,
                        dateText: dateRangeText(for: arc),
                        recordCount: reflection.sourceRecordIDs.count
                    ))
                    .frame(height: 164)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var activeArcListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.string("common.active_phases", default: "Active Phases"))
                .font(.headline)

            ForEach(acceptedArcs, id: \.id) { arc in
                NavigationLink {
                    TemporalArcDetailView(arc: arc)
                } label: {
                    let evidenceView = memoryRepository.arcEvidenceView(for: arc.id)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(arc.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(arc.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                        if let reflection = evidenceView?.linkedReflection {
                            Text(reflection.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.9))
                                .lineLimit(1)
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

    private var archivedArcListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.string("common.archived_phases", default: "Archived Phases"))
                .font(.headline)

            Text(localization.string("common.archived_phases_note", default: "These phases are no longer in the active layer, but their evidence is still preserved."))
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(archivedArcs.prefix(6), id: \.id) { arc in
                NavigationLink {
                    TemporalArcDetailView(arc: arc)
                } label: {
                    let evidenceView = memoryRepository.arcEvidenceView(for: arc.id)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(arc.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            SignalPill(title: "Archived", tint: .secondary)
                        }

                        Text(arc.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)

                        if let evidenceView {
                            Text(arcEvidenceSummary(for: evidenceView))
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.8))
                                .lineLimit(1)
                        }

                        Text(localization.string("common.archived_lifecycle_state", default: "Archived lifecycle state"))
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        HomeSectionPlaceholderView(
            systemImage: "timeline.selection",
            title: "Arcs",
            subtitle: "阶段入口已经接入，等更多记忆和分析累积后，这里会展示长期阶段。"
        )
    }

    private func dateRangeText(for arc: TemporalArc) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: arc.startDate, to: arc.endDate)
    }

    private func arcEvidenceSummary(for evidenceView: SproutMemoryRepository.ArcEvidenceView) -> String {
        let parts = [
            evidenceView.relatedRecordShells.isEmpty ? nil : "\(evidenceView.relatedRecordShells.count) memories",
            evidenceView.relatedAnalyses.isEmpty ? nil : "\(evidenceView.relatedAnalyses.count) analyses",
            evidenceView.linkedEntities.isEmpty ? nil : "\(evidenceView.linkedEntities.count) entities"
        ].compactMap { $0 }

        return parts.isEmpty ? "No linked evidence yet" : parts.joined(separator: " · ")
    }
}
