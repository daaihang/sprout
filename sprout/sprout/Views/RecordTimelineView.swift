import SwiftUI
import SwiftData
import UIKit

struct RecordTimelineView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.modelContext) private var modelContext

    let selectedDate: Date

    @State private var hasPerformedInitialScroll = false
    @State private var records: [Record] = []
    @State private var fetchLimit = 120
    @State private var isLoadingMore = false

    private let fetchBatchSize = 120

    private var daySections: [RecordDaySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.createdAt)
        }

        return grouped
            .map { date, records in
                RecordDaySection(
                    id: date,
                    records: records.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { $0.id > $1.id }
    }

    private var sectionIDs: [Double] {
        daySections.map { $0.id.timeIntervalSinceReferenceDate }
    }

    var body: some View {
        Group {
            if daySections.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 120)
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(daySections) { section in
                            Section(sectionTitle(for: section.id)) {
                                ForEach(Array(section.records.enumerated()), id: \.element.id) { index, record in
                                    RecordTimelineRow(record: record)
                                        .id(record.id)
                                        .task {
                                            await loadMoreIfNeeded(currentRecord: record, sectionIndex: index)
                                        }
                                }
                            }
                            .id(sectionAnchorID(for: section))
                        }
                    }
                    .listStyle(.insetGrouped)
                    .contentMargins(.bottom, 104, for: .scrollContent)
                    .task(id: sectionIDs) {
                        guard !hasPerformedInitialScroll, !daySections.isEmpty else { return }
                        hasPerformedInitialScroll = true
                        await scroll(to: selectedDate, using: proxy, animated: false)
                    }
                    .onChange(of: selectedDate) { _, newValue in
                        Task {
                            await ensureVisibleWindow(for: newValue)
                            await scroll(to: newValue, using: proxy, animated: true)
                        }
                    }
                }
            }
        }
        .background(Color.clear)
        .task {
            await reloadRecords()
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            Task {
                await reloadRecords()
            }
        }
    }

    @MainActor
    private func reloadRecords() async {
        records = fetchRecords(limit: fetchLimit)
    }

    @MainActor
    private func ensureVisibleWindow(for date: Date) async {
        let targetDay = Calendar.current.startOfDay(for: date)
        guard !records.isEmpty else {
            await reloadRecords()
            return
        }

        while !records.isEmpty,
              records.last?.createdAt ?? .distantPast > targetDay,
              hasMoreRecords
        {
            fetchLimit += fetchBatchSize
            records = fetchRecords(limit: fetchLimit)
        }
    }

    @MainActor
    private func loadMoreIfNeeded(currentRecord: Record, sectionIndex: Int) async {
        guard !isLoadingMore,
              hasMoreRecords,
              isNearWindowEnd(record: currentRecord, sectionIndex: sectionIndex)
        else {
            return
        }

        isLoadingMore = true
        fetchLimit += fetchBatchSize
        records = fetchRecords(limit: fetchLimit)
        isLoadingMore = false
    }

    private func isNearWindowEnd(record: Record, sectionIndex: Int) -> Bool {
        guard let lastSection = daySections.last else { return false }
        guard Calendar.current.isDate(lastSection.id, inSameDayAs: Calendar.current.startOfDay(for: record.createdAt)) else {
            return false
        }
        return sectionIndex >= max(lastSection.records.count - 12, 0)
    }

    private var hasMoreRecords: Bool {
        records.count >= fetchLimit
    }

    private func fetchRecords(limit: Int) -> [Record] {
        var descriptor = FetchDescriptor<Record>(
            sortBy: [SortDescriptor(\Record.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func scroll(to date: Date, using proxy: ScrollViewProxy, animated: Bool) async {
        guard let target = targetScrollID(for: date) else { return }

        try? await Task.sleep(for: .milliseconds(50))
        await MainActor.run {
            if animated {
                withAnimation(.spring(duration: 0.32, bounce: 0.08)) {
                    proxy.scrollTo(target, anchor: .top)
                }
            } else {
                proxy.scrollTo(target, anchor: .top)
            }
        }
    }

    private func targetScrollID(for requestedDate: Date) -> String? {
        guard !daySections.isEmpty else { return nil }

        let targetDay = Calendar.current.startOfDay(for: requestedDate)
        if let exactSection = daySections.first(where: { Calendar.current.isDate($0.id, inSameDayAs: targetDay) }) {
            return sectionAnchorID(for: exactSection)
        }

        return daySections.min {
            abs($0.id.timeIntervalSince(targetDay)) < abs($1.id.timeIntervalSince(targetDay))
        }.map(sectionAnchorID(for:))
    }

    private func sectionAnchorID(for section: RecordDaySection) -> String {
        "record-day-\(section.id.timeIntervalSinceReferenceDate)"
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.secondary.opacity(0.45))

            Text(localization.string("timeline.empty.title", default: "No records yet"))
                .font(.headline)
                .foregroundStyle(.primary)

            Text(localization.string("timeline.empty.subtitle", default: "Records you create from the composer and quick-add flows will appear here in chronological order."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if calendar.isDate(date, inSameDayAs: today) {
            return localization.string("content.date.today", default: "Today")
        }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        if calendar.isDate(date, inSameDayAs: yesterday) {
            return localization.string("content.date.yesterday", default: "Yesterday")
        }

        return localization.templateDateString(from: date, template: "MMM d EEEE")
    }
}

struct RecordDaySection: Identifiable {
    let id: Date
    let records: [Record]
}

struct RecordTimelineRow: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(SproutMemoryRepository.self) private var memoryRepository

    let record: Record

    private var evidence: RecordEvidenceProjector.Projection {
        RecordEvidenceProjector(localization: localization)
            .project(record: record, memoryView: memoryRepository.memoryView(for: record.id))
    }

    var body: some View {
        NavigationLink(
            destination: RecordDetailView(
                record: record,
                focusedSection: evidence.preferredFocusedSection
            )
        ) {
            HStack(alignment: .top, spacing: 14) {
                preview

                VStack(alignment: .leading, spacing: 6) {
                    Text(timeLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Text(headlineText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    if let supportingText, !supportingText.isEmpty {
                        Text(supportingText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }

                    if !metaLine.isEmpty {
                        Text(metaLine)
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.85))
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var preview: some View {
        if evidence.primaryKind == .photo, let image = evidence.photoPreviewImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else if evidence.primaryKind == .emotion, let mood = evidence.mood {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(mood.color.opacity(0.16))
                .frame(width: 62, height: 62)
                .overlay(
                    Text(mood.emoji)
                        .font(.system(size: 30))
                )
        } else if evidence.primaryKind == .people, let initials = evidence.primaryPersonInitials {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.14))
                .frame(width: 62, height: 62)
                .overlay(
                    Text(initials)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                )
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(previewTint.opacity(0.14))
                .frame(width: 62, height: 62)
                .overlay(
                    Image(systemName: previewSymbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(previewTint)
                )
        }
    }

    private var previewSymbol: String {
        switch evidence.primaryKind {
        case .weather:
            return evidence.weatherCondition?.sfSymbol ?? evidence.primaryKind.symbolName
        default:
            return evidence.primaryKind.symbolName
        }
    }

    private var previewTint: Color {
        switch evidence.primaryKind {
        case .weather:
            return evidence.weatherCondition?.color ?? .accentColor
        case .audio:
            return .orange
        case .music:
            return .pink
        case .map:
            return .green
        case .todo:
            return .accentColor
        case .link:
            return .blue
        default:
            return .accentColor
        }
    }

    private var headlineText: String {
        evidence.headlineText
    }

    private var supportingText: String? {
        evidence.supportingText
    }

    private var metaLine: String {
        evidence.metaLabels.joined(separator: " · ")
    }

    private var timeLabel: String {
        localization.templateDateString(from: record.createdAt, template: "HH:mm")
    }
}
