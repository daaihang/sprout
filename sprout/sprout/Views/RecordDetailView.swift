import SwiftUI
import UIKit
import MapKit
import AVFoundation

// MARK: - RecordDetailView

/// Full-screen detail view for a single Record.
/// The `focusedSection` parameter determines which content block appears first —
/// so tapping a MusicCard opens this view with music at the top, while tapping
/// a QuoteCard shows the text first. All content still follows below.
@MainActor
struct RecordDetailView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(SproutMemoryRepository.self) private var memoryRepository
    let record: Record
    var focusedSection: RecordSection = .text

    // MARK: Section ordering

    private var orderedSections: [RecordSection] {
        var all = availableSections
        if let idx = all.firstIndex(of: focusedSection) {
            all.remove(at: idx)
            all.insert(focusedSection, at: 0)
        }
        return all
    }

    private var availableSections: [RecordSection] {
        var sections: [RecordSection] = []
        if textArtifact != nil { sections.append(.text) }
        if hasArtifacts(.photo) { sections.append(.photo) }
        if hasArtifacts(.audio) { sections.append(.audio) }
        if hasArtifacts(.link) { sections.append(.link) }
        if hasArtifacts(.todo) { sections.append(.todo) }
        if hasArtifacts(.music) { sections.append(.music) }
        if primaryArtifact(for: .location) != nil || evidence.linkedLocationName != nil { sections.append(.map) }
        if primaryArtifact(for: .weather) != nil || evidence.weatherCondition != nil { sections.append(.weather) }
        if !peopleArtifactRows.isEmpty || !analysisPeopleReferences.isEmpty || evidence.primaryPersonName != nil { sections.append(.people) }
        if evidence.mood != nil { sections.append(.emotion) }
        return sections
    }

    private var memoryView: SproutMemoryRepository.RecordMemoryView? {
        memoryRepository.memoryView(for: record.id)
    }

    private var evidence: RecordEvidenceProjector.Projection {
        RecordEvidenceProjector(localization: localization)
            .project(record: record, memoryView: memoryView)
    }

    private var linkedArcs: [TemporalArc] {
        memoryRepository.temporalArcs
            .filter { $0.sourceRecordIDs.contains(record.id) && $0.status == .accepted }
            .sorted { lhs, rhs in
                if lhs.endDate == rhs.endDate {
                    return lhs.intensityScore > rhs.intensityScore
                }
                return lhs.endDate > rhs.endDate
            }
    }

    private var linkedPhaseReflection: ReflectionSnapshot? {
        linkedArcs.first.flatMap { memoryRepository.linkedReflection(forArcID: $0.id) }
    }

    private var linkedRecordReflection: ReflectionSnapshot? {
        memoryView?.reflection
    }

    private var artifacts: [Artifact] {
        memoryView?.artifacts ?? []
    }

    private var textArtifact: Artifact? {
        primaryArtifact(for: .text)
    }

    private var analysisSnapshot: RecordAnalysisSnapshot? {
        evidence.analysis
    }

    private var peopleArtifactRows: [PersonCardItem] {
        sectionArtifacts(for: .personMention).map { artifact in
            PersonCardItem(
                id: artifact.id,
                name: artifact.title,
                relationship: artifact.metadata["relationship"] ?? "",
                mentionCount: 1
            )
        }
    }

    private var analysisPeopleReferences: [EntityReference] {
        (analysisSnapshot?.entities ?? [])
            .filter { $0.kind == .person }
    }

    private var artifactEntityNamesByArtifactID: [UUID: [String]] {
        guard let memoryView else { return [:] }
        let entityMap = Dictionary(uniqueKeysWithValues: memoryView.linkedEntities.map { ($0.id, $0) })
        let artifactIDs = Set(memoryView.artifacts.map(\.id))
        let groupedLinks = Dictionary(grouping: memoryRepository.artifactEntityLinks.filter { artifactIDs.contains($0.artifactID) }, by: \.artifactID)

        return groupedLinks.mapValues { links in
            links.compactMap { entityMap[$0.entityID]?.displayName }
                .uniqued()
                .sorted()
        }
    }

    private var evidenceSummaryText: String? {
        guard let memoryView else { return nil }

        var parts: [String] = []
        if !memoryView.artifacts.isEmpty {
            parts.append("\(memoryView.artifacts.count) artifacts")
        }
        if !memoryView.linkedEntities.isEmpty {
            parts.append("\(memoryView.linkedEntities.count) entities")
        }
        if !linkedArcs.isEmpty {
            parts.append("\(linkedArcs.count) phases")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func sectionArtifacts(for kind: ArtifactKind) -> [Artifact] {
        artifacts
            .filter { $0.kind == kind }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.updatedAt < rhs.updatedAt
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    private func primaryArtifact(for kind: ArtifactKind) -> Artifact? {
        sectionArtifacts(for: kind).first
    }

    private func hasArtifacts(_ kind: ArtifactKind) -> Bool {
        primaryArtifact(for: kind) != nil
    }

    private func coordinate(from artifact: Artifact) -> CLLocationCoordinate2D? {
        guard let latitude = Double(artifact.metadata["latitude"] ?? ""),
              let longitude = Double(artifact.metadata["longitude"] ?? "") else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var artifactSummaryLine: String {
        guard let memoryView else { return "No artifact projection yet" }
        let grouped = Dictionary(grouping: memoryView.artifacts, by: \.kind)
        let parts = grouped
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { kind, artifacts in
                if artifacts.count == 1 {
                    return kindLabel(kind)
                }
                return "\(artifacts.count) \(kindLabel(kind).lowercased())"
        }
        return parts.isEmpty ? "No artifacts attached" : parts.joined(separator: " · ")
    }

    private var locationCoordinate: CLLocationCoordinate2D? {
        if let artifact = primaryArtifact(for: .location),
           let coordinate = coordinate(from: artifact) {
            return coordinate
        }
        return nil
    }

    private var locationTitleText: String? {
        if let artifact = primaryArtifact(for: .location) {
            return nonEmpty(artifact.title) ?? evidence.linkedLocationName
        }
        return evidence.linkedLocationName
    }

    private var locationSummaryText: String? {
        if let artifact = primaryArtifact(for: .location) {
            return nonEmpty(artifact.summary)
        }
        return nil
    }

    private var weatherEvidence: (condition: WeatherCondition, temperature: Double, locationText: String?, observedAt: Date?, insight: String?)? {
        if let artifact = primaryArtifact(for: .weather),
           let condition = WeatherCondition(rawValue: artifact.metadata["condition"] ?? artifact.title) {
            return (
                condition: condition,
                temperature: Double(artifact.metadata["temperature"] ?? "") ?? 20,
                locationText: artifact.metadata["location"] ?? nonEmpty(artifact.summary) ?? evidence.linkedLocationName,
                observedAt: artifact.createdAt,
                insight: nonEmpty(artifact.textContent)
            )
        }
        return nil
    }

    private var resolvedPeople: [PersonCardItem] {
        if !peopleArtifactRows.isEmpty {
            return peopleArtifactRows
        }

        let analysisPeople = analysisPeopleReferences.map {
            PersonCardItem(
                id: $0.id,
                name: $0.name,
                relationship: $0.kind.badgeLabel,
                mentionCount: 1
            )
        }

        if !analysisPeople.isEmpty {
            return analysisPeople
        }

        return []
    }

    // MARK: Body

    @State private var showReflectionEditor = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                captureShellHeader
                if let memoryView, !memoryView.artifacts.isEmpty {
                    artifactOverviewSection(memoryView)
                }
                if let firstArc = linkedArcs.first {
                    phaseContextSection(firstArc, reflection: linkedPhaseReflection)
                }
                if let linkedRecordReflection {
                    recordReflectionSection(linkedRecordReflection)
                }
                ForEach(orderedSections, id: \.self) { section in
                    sectionView(for: section)
                }
                if let memoryView, memoryView.analysis != nil || !memoryView.linkedEntities.isEmpty {
                    memoryInsightsSection(memoryView)
                }
                metadataFooter.padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .padding(.bottom, 40)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReflectionEditor) {
            ReflectionEditView(
                reflectionID: linkedRecordReflection?.id,
                recordID: record.id,
                arcID: nil
            )
        }
    }

    private var captureShellHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(localization.string("common.capture_shell", default: "Capture Shell"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(captureTitleText)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(captureSubtitleText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                shellMetaChip(icon: "shippingbox", text: artifactCountText)
                if let source = memoryView?.recordShell.captureSource.rawValue {
                    shellMetaChip(icon: "square.and.pencil", text: source.replacingOccurrences(of: "_", with: " "))
                }
                if let mood = memoryView?.recordShell.userMood, !mood.isEmpty {
                    shellMetaChip(icon: "face.smiling", text: mood)
                }
            }
        }
        .detailCard()
    }

    @ViewBuilder
    private func artifactOverviewSection(_ memoryView: SproutMemoryRepository.RecordMemoryView) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "shippingbox", title: "Artifacts in This Capture")

            Text(artifactSummaryLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(memoryView.artifacts.prefix(6), id: \.id) { artifact in
                    NavigationLink {
                        ArtifactDetailView(artifact: artifact)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            ArtifactRowView(
                                artifact: artifact,
                                entityNames: artifactEntityNamesByArtifactID[artifact.id] ?? [],
                                style: .compact
                            )
                            if let evidenceLine = artifactEvidenceLine(for: artifact) {
                                Text(evidenceLine)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .padding(.leading, 46)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .detailCard()
    }

    @ViewBuilder
    private func phaseContextSection(_ arc: TemporalArc, reflection: ReflectionSnapshot?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "timeline.selection", title: "Phase Context")

            NavigationLink {
                TemporalArcDetailView(arc: arc)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(arc.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(arc.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    Text(dateRangeText(for: arc))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            if let reflection {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localization.string("common.current_reflection", default: "Current Reflection"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(reflection.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(reflection.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .detailCard()
    }

    @ViewBuilder
    private func recordReflectionSection(_ reflection: ReflectionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "sparkles", title: "Record Reflection")

            NavigationLink {
                ReflectionDetailView(reflection: reflection)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(reflection.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(reflection.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                    HStack(spacing: 8) {
                        SignalPill(title: reflection.statusDisplayText, tint: reflectionStatusTint(reflection.status))
                        SignalPill(title: "\(reflection.sourceArtifactIDs.count) artifacts", tint: .blue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .detailCard()
    }

    private var navigationTitle: String {
        let headline = evidence.headlineText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !headline.isEmpty {
            return String(headline.prefix(24))
        }
        if let location = evidence.linkedLocationName, !location.isEmpty {
            return location
        }
        return t("detail.navigation.record", "Entry")
    }

    private var captureTitleText: String {
        if let shell = memoryView?.recordShell, !shell.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(shell.rawText.prefix(120))
        }
        let headline = evidence.headlineText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !headline.isEmpty {
            return String(headline.prefix(120))
        }
        if let loc = evidence.linkedLocationName, !loc.isEmpty {
            return loc
        }
        return "Untitled Capture"
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

    private var captureSubtitleText: String {
        if let supporting = evidence.supportingText, !supporting.isEmpty {
            return supporting
        }
        if let analysis = evidence.analysis {
            let emotion = analysis.emotionLabel.isEmpty ? "Analysis ready" : analysis.emotionLabel.capitalized
            return "\(emotion) · \(artifactCountText)"
        }
        if !evidence.metaLabels.isEmpty {
            return evidence.metaLabels.joined(separator: " · ")
        }
        return artifactCountText
    }

    private var artifactCountText: String {
        let count = evidence.artifacts.count
        switch count {
        case 0:
            return "0 artifacts"
        case 1:
            return "1 artifact"
        default:
            return "\(count) artifacts"
        }
    }

    // MARK: Section dispatcher

    @ViewBuilder
    private func sectionView(for section: RecordSection) -> some View {
        switch section {
        case .text:     textSection
        case .emotion:  emotionSection
        case .weather:  weatherSection
        case .photo:    photoSection
        case .music:    musicSection
        case .audio:    audioSection
        case .link:     linkSection
        case .map:      mapSection
        case .todo:     todoSection
        case .people:   peopleSection
        case .todayInHistory:
            EmptyView()
        }
    }

    // MARK: - Text

    private var textSection: some View {
        let bodyText = nonEmpty(textArtifact?.textContent) ?? ""
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(icon: "text.alignleft", title: t("detail.section.body", "Body"))
            Text(bodyText)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .detailCard()
    }

    // MARK: - Emotion

    @ViewBuilder
    private var emotionSection: some View {
        if let mood = evidence.mood {
            let intensity = memoryView?.recordShell.userIntensity ?? record.userIntensity ?? 3
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "face.smiling", title: t("detail.section.emotion", "Emotion"))
                HStack(spacing: 14) {
                    Text(mood.emoji).font(.system(size: 48))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(mood.label).font(.title3.weight(.semibold))
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { i in
                                Circle()
                                    .fill(i <= intensity ? mood.color : mood.color.opacity(0.2))
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                    Spacer()
                }
            }
            .detailCard()
        }
    }

    // MARK: - Weather

    @ViewBuilder
    private var weatherSection: some View {
        if let weather = weatherEvidence {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "cloud.sun.fill", title: t("detail.section.weather", "Weather"))
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(weather.temperature))°")
                            .font(.system(size: 42, weight: .semibold, design: .rounded))
                        Text(weather.condition.label).font(.subheadline).foregroundStyle(.secondary)
                        if let locationText = weather.locationText, !locationText.isEmpty {
                            Label(locationText, systemImage: "location.fill")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if let observedAt = weather.observedAt {
                            Label(observedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: weather.condition.sfSymbol)
                        .font(.system(size: 48))
                        .foregroundStyle(weather.condition.color)
                        .symbolRenderingMode(.multicolor)
                }
                if let insight = weather.insight {
                    Text(insight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .detailCard()
        }
    }

    // MARK: - Photos

    private var photoSection: some View {
        return PhotoEvidenceSection(
            artifacts: artifacts
        )
    }

    // MARK: - Music

    private var musicSection: some View {
        let musicArtifact = primaryArtifact(for: .music)
        return MusicEvidenceSection(
            artifact: musicArtifact
        )
    }

    // MARK: - Links

    @ViewBuilder
    private var audioSection: some View {
        let audioArtifact = primaryArtifact(for: .audio)
        
        if audioArtifact != nil {
            AudioEvidenceSection(
                artifact: audioArtifact,
                audioDurationString: audioDurationString
            )
        }
    }

    @ViewBuilder
    private var linkSection: some View {
        LinkEvidenceSection(
            artifacts: sectionArtifacts(for: .link)
        )
    }

    @ViewBuilder
    private var peopleSection: some View {
        let people = resolvedPeople
        if !people.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "person.2.fill", title: t("detail.section.people", "People"))
                ForEach(people, id: \.id) { person in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.14))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(person.initials)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.displayName)
                                .font(.subheadline.weight(.semibold))
                            if !person.subtitle.isEmpty {
                                Text(person.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if person.mentionCount > 0 {
                            Text("\(person.mentionCount)x")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if !analysisPeopleReferences.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(localization.string("common.ai_evidence", default: "AI Evidence"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TokenPillRow(
                            values: analysisPeopleReferences.map { "\($0.kind.badgeLabel): \($0.name)" },
                            tint: .blue
                        )
                    }
                }
            }
            .detailCard()
        }
    }

    // MARK: - Map

    @ViewBuilder
    private var mapSection: some View {
        if let coordinate = locationCoordinate {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "map.fill", title: t("detail.section.location", "Location"))
                MapSnapshotView(coordinate: coordinate)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                if let title = locationTitleText {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }
                if let summary = locationSummaryText {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .detailCard()
        }
    }

    // MARK: - Todo

    @ViewBuilder
    private var todoSection: some View {
        TodoEvidenceSection(
            artifact: primaryArtifact(for: .todo)
        )
    }

    @ViewBuilder
    private func memoryInsightsSection(_ memoryView: SproutMemoryRepository.RecordMemoryView) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "sparkles.rectangle.stack", title: t("detail.section.memory_insights", "Memory Insights"))

            if let analysis = memoryView.analysis {
                VStack(alignment: .leading, spacing: 8) {
                    Text(analysis.emotionLabel.capitalized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(analysis.insight)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if let followUpQuestion = analysis.followUpQuestion, !followUpQuestion.isEmpty {
                        Text(followUpQuestion)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    if let salienceText = analysis.saliencePercentageText {
                        Text(salienceText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if !analysis.tags.isEmpty {
                        TokenPillRow(values: analysis.tags, tint: .accentColor)
                    }

                    if !analysis.retrievalTerms.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(localization.string("common.retrieval_terms", default: "Retrieval Terms"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TokenPillRow(values: analysis.retrievalTerms, tint: .green)
                        }
                    }

                    if !analysis.entities.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(t("detail.memory.ai_entities", "AI Entities"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TokenPillRow(
                                values: analysis.entities.map { "\($0.kind.badgeLabel): \($0.name)" },
                                tint: .purple
                            )
                        }
                    }

                    if let reflectionHint = analysis.reflectionHint, !reflectionHint.isEmpty {
                        EvidenceCalloutCard(title: "Reflection Hint", bodyText: reflectionHint)
                    }

                    if let evidenceSummaryText {
                        EvidenceCalloutCard(
                            title: "Evidence",
                            bodyText: "This analysis is currently grounded in \(evidenceSummaryText)."
                        )
                    }
                }
            }

            if !memoryView.linkedEntities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("detail.memory.entities", "Linked Entities"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(memoryView.linkedEntities, id: \.id) { entity in
                        NavigationLink {
                            MemoryEntityDetailView(entityID: entity.id)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text(entity.kind.badgeLabel)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(entity.kind.tintColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(entity.kind.tintColor.opacity(0.12), in: Capsule())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entity.displayName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    if !entity.summary.isEmpty {
                                        Text(entity.summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !linkedArcs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localization.string("common.related_phases", default: "Related Phases"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(linkedArcs.prefix(3), id: \.id) { arc in
                        NavigationLink {
                            TemporalArcDetailView(arc: arc)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(arc.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(arc.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .detailCard()
    }

    // MARK: - Metadata footer

    private var metadataFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            HStack(spacing: 16) {
                Label(formattedDate(record.createdAt), systemImage: "clock")
                if let loc = locationTitleText, !loc.isEmpty {
                    Label(loc, systemImage: "location")
                }
            }
            .font(.caption).foregroundStyle(.secondary)

            Button(action: { showReflectionEditor = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text(
                        localization.string(
                            "common.create_reflection",
                            default: linkedRecordReflection == nil ? "Create Reflection" : "Edit Reflection"
                        )
                    )
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(Color.purple)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        localization.templateDateString(from: date, template: "MMM d HH:mm")
    }

    private func kindLabel(_ kind: ArtifactKind) -> String {
        switch kind {
        case .text: return "Text"
        case .photo: return "Photo"
        case .audio: return "Voice"
        case .music: return "Music"
        case .link: return "Link"
        case .location: return "Location"
        case .weather: return "Weather"
        case .todo: return "To-Do"
        case .personMention: return "Person"
        case .decisionNote: return "Decision"
        case .book: return "Book"
        case .film: return "Film"
        case .game: return "Game"
        case .ticket: return "Ticket"
        case .healthMetric: return "Health"
        }
    }

    private func artifactEvidenceLine(for artifact: Artifact) -> String? {
        var parts: [String] = []

        if let entityNames = artifactEntityNamesByArtifactID[artifact.id], !entityNames.isEmpty {
            parts.append("Linked to \(entityNames.prefix(3).joined(separator: ", "))")
        }

        if artifact.kind == .photo || artifact.kind == .audio {
            let payload = artifact.binaryPayload == nil ? "payload missing" : "payload attached"
            parts.append(payload)
        }

        if let arc = linkedArcs.first(where: { $0.sourceArtifactIDs.contains(artifact.id) }) {
            parts.append("Part of \(arc.title)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func shellMetaChip(icon: String, text: String) -> some View {
        Label(text.capitalized, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08), in: Capsule())
    }

    private func dateRangeText(for arc: TemporalArc) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: arc.startDate, to: arc.endDate)
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }

    private func nonEmpty(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Computes audio duration from raw data for use as a fallback label.
    /// The actual duration is recalculated within AudioCard via AVAudioPlayer, so this is a fallback only.
    private func audioDurationString(from data: Data?) -> String {
        guard let data = data, !data.isEmpty else { return "" }
        do {
            let audioPlayer = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
            let totalSeconds = max(Int(audioPlayer.duration.rounded()), 0)
            return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
        } catch {
            return ""
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Map snapshot

private struct MapSnapshotView: View {
    let coordinate: CLLocationCoordinate2D
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .overlay(ProgressView())
                    .task { await loadSnapshot() }
            }
        }
    }

    @MainActor
    private func loadSnapshot() async {
        let opts = MKMapSnapshotter.Options()
        opts.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 800, longitudinalMeters: 800
        )
        opts.size = CGSize(width: 360, height: 200)
        opts.scale = UIScreen.main.scale
        if let snap = try? await MKMapSnapshotter(options: opts).start() {
            image = snap.image
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Preview

#Preview {
    let repository = SproutMemoryRepository()
    let createdAt = Date()
    let aggregate = SproutMemoryAggregate(
        recordShell: RecordShell(
            createdAt: createdAt,
            updatedAt: createdAt,
            rawText: "今天读到了一句话，让人感触很深：生活不是等待暴风雨过去，而是学会在雨中起舞。",
            captureSource: .composer,
            artifactIDs: [],
            userMood: MoodType.calm.rawValue,
            userIntensity: 4
        ),
        artifacts: [
            Artifact(
                kind: .text,
                title: "一句触动很深的话",
                summary: "关于在变化中学会行动的提醒。",
                textContent: "今天读到了一句话，让人感触很深：生活不是等待暴风雨过去，而是学会在雨中起舞。",
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ],
        knownEntities: []
    )
    try? repository.upsertAggregate(aggregate)

    return NavigationStack {
        MemoryRecordDetailView(recordID: aggregate.recordShell.id, focusedSection: .text)
    }
    .environment(repository)
}
