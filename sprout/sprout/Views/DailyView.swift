import SwiftUI
import SwiftData

// MARK: - DailyView

/// Displays the card grid for a single calendar day.
/// Owns a @Query filtered to [startOfDay, endOfDay) so the grid automatically
/// updates when records are added, deleted, or modified (e.g. cardUnits change).
struct DailyView: View {
    let date: Date

    @Query private var records: [Record]

    init(date: Date) {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!
        _records = Query(
            filter: #Predicate<Record> { r in
                r.createdAt >= start && r.createdAt < end
            },
            sort: \Record.createdAt, order: .reverse
        )
        self.date = date
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if records.isEmpty {
                EmptyDayView(date: date)
                    .padding(.top, 80)
            } else {
                CardGridView(items: gridItems)
                    .padding(.top, 24)
                    .padding(.bottom, 96)
            }
        }
    }

    private var gridItems: [GridItem] {
        records
            .flatMap { RecordMapper.allCards(record: $0) }
            .map { info in
                GridItem(
                    card: AnyView(CardWrapper(info: info)),
                    columns: info.columns,
                    units: info.units
                )
            }
    }
}

// MARK: - CardWrapper

/// Wraps a single DashboardCardInfo with NavigationLink and a long-press context menu
/// for resizing the card (persisted via record.cardUnits).
struct CardWrapper: View {
    @Environment(\.modelContext) private var modelContext
    let info: DashboardCardInfo

    var body: some View {
        NavigationLink(
            destination: RecordDetailView(
                record: info.record,
                focusedSection: info.focusedSection
            )
        ) {
            info.cardView
        }
        .buttonStyle(.plain)
        .contextMenu {
            Label("调整卡片尺寸", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.subheadline.weight(.semibold))

            Divider()

            Button {
                resize(to: 4)
            } label: {
                Label("大卡片  4×4", systemImage: "square.fill")
            }

            Button {
                resize(to: 2)
            } label: {
                Label("中等  4×2", systemImage: "rectangle.fill")
            }

            Button {
                resize(to: 1)
            } label: {
                Label("窄条  4×1", systemImage: "minus.rectangle.fill")
            }

            Divider()

            Button(role: .destructive) {
                deleteRecord()
            } label: {
                Label("删除记录", systemImage: "trash")
            }
        }
        .contentShape(.contextMenuPreview,
                      RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func resize(to units: Int) {
        info.record.cardUnits = units
    }

    private func deleteRecord() {
        modelContext.delete(info.record)
    }
}

// MARK: - EmptyDayView

struct EmptyDayView: View {
    let date: Date

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))

            VStack(spacing: 6) {
                Text(dateLabel)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("还没有记录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("点击下方输入框开始今天的第一条")
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    private var dateLabel: String {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        if cal.isDate(date, inSameDayAs: today) { return "今天" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 · EEEE"
        return f.string(from: date)
    }
}
