import SwiftUI
import SwiftData
import UIKit

struct RecordTimelineScrollView: View {
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
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(daySections) { section in
                                Section {
                                    VStack(spacing: 0) {
                                        ForEach(Array(section.records.enumerated()), id: \.element.id) { index, record in
                                            RecordTimelineRow(record: record)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.clear)
                                                .id(record.id)
                                                .task {
                                                    await loadMoreIfNeeded(currentRecord: record, sectionIndex: index)
                                                }

                                            if record.id != section.records.last?.id {
                                                Divider()
                                                    .padding(.leading, 92)
                                            }
                                        }
                                    }
                                    .background(Color.clear)
                                } header: {
                                    sectionHeader(for: section.id)
                                        .id(sectionAnchorID(for: section))
                                }
                            }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 104)
                    }
                    .background(Color.clear)
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
        .overlay {
            ClearAncestorBackgroundView(clearDescendantScrollViews: true)
                .allowsHitTesting(false)
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

    private func sectionHeader(for date: Date) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.96))
                .overlay(Color.clear)

            Text(sectionTitle(for: date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
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
