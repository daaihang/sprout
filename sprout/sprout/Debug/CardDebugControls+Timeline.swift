import SwiftUI

extension CardDebugView {
    @ViewBuilder
    var todayInHistoryControlsSections: some View {
        Section {
            TextField(t("common.month_day_label", "Month Day Label"), text: $todayInHistoryData.monthDayLabel)

            if let config = todayInHistorySystemConfig {
                Toggle(
                    t("common.debug.enable_today_in_history", "Enable Today in History Card"),
                    isOn: binding(for: config, keyPath: \.isEnabled)
                )

                Picker(t("common.width", "Width"), selection: allowedWidthBinding(for: config)) {
                    ForEach(availableWidths(for: config.heightUnits), id: \.self) { width in
                        Text("\(width)").tag(width)
                    }
                }
                .pickerStyle(.segmented)

                Picker(t("common.height", "Height"), selection: allowedHeightBinding(for: config)) {
                    ForEach(availableHeights(for: config.widthColumns), id: \.self) { height in
                        Text("\(height)").tag(height)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent(t("common.sort", "Sort")) {
                    Stepper(
                        "\(Int(config.dashboardOrder))",
                        value: binding(for: config, keyPath: \.dashboardOrder),
                        in: -20_000...20_000,
                        step: 100
                    )
                }
            } else {
                Button {
                    createTodayInHistorySystemConfig()
                } label: {
                    Label(t("common.debug.create_system_card_config", "Create System Card Config"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
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
