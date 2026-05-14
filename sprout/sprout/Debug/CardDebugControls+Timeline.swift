import SwiftUI

extension CardDebugView {
    @ViewBuilder
    var todayInHistoryControlsSections: some View {
        Section {
            TextField(t("common.month_day_label", "Month Day Label"), text: $todayInHistoryData.monthDayLabel)

            Text(t("common.debug.today_in_history_layout_note", "Today in History visibility and layout now come from CompositionItem state in the home board, not a separate system-card config."))
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text(t("common.debug.controls", "Debug Controls"))
        } footer: {
            Text(t("common.debug.system_card_config", "System Card Config"))
        }

        Section {
            Button(t("common.debug.entry_count_one", "1 Entry")) {
                todayInHistoryData = makeTodayInHistorySample(entryCount: 1)
            }
            Button(t("common.debug.entry_count_three", "3 Entries")) {
                todayInHistoryData = makeTodayInHistorySample(entryCount: 3)
            }
            Button(t("common.debug.entry_count_six", "6 Entries")) {
                todayInHistoryData = makeTodayInHistorySample(entryCount: 6)
            }
            Button(t("common.debug.no_history", "No History")) {
                todayInHistoryData = TodayInHistoryCardData(monthDayLabel: "May 11", entries: [])
            }
            Button(t("common.clear_data", "Clear Data"), role: .destructive) {
                todayInHistoryData = TodayInHistoryCardData(monthDayLabel: "May 11", entries: [])
            }
        }
    }
}
