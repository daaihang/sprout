import SwiftUI

struct HomeDrawerCalendarStrip: View {
    @Environment(AppLocalization.self) private var localization
    @Binding var selectedDate: Date
    let horizontalInset: CGFloat
    let isPresented: Bool

    @State private var visibleRange: ClosedRange<Int>
    @State private var visibleOffsets: [Int] = []

    private let calendar = Calendar.current
    private let itemSize: CGFloat = 44
    private let itemSpacing: CGFloat = 8
    private let trackHeight: CGFloat = 58
    private let initialPastDays = 28
    private let initialFutureDays = 28
    private let expansionBatch = 21
    private let hardLimitDays = 365 * 20

    init(selectedDate: Binding<Date>, horizontalInset: CGFloat, isPresented: Bool) {
        _selectedDate = selectedDate
        self.horizontalInset = horizontalInset
        self.isPresented = isPresented

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let normalizedSelection = calendar.startOfDay(for: selectedDate.wrappedValue)
        let selectionOffset = calendar.dateComponents([.day], from: today, to: normalizedSelection).day ?? 0
        let lower = max(selectionOffset - initialPastDays, -hardLimitDays)
        let upper = min(selectionOffset + initialFutureDays, hardLimitDays)
        _visibleRange = State(initialValue: lower...upper)
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var normalizedSelectedDate: Date {
        calendar.startOfDay(for: selectedDate)
    }

    private var selectedOffset: Int {
        calendar.dateComponents([.day], from: today, to: normalizedSelectedDate).day ?? 0
    }

    private var dayOffsets: [Int] {
        Array(visibleRange)
    }

    private var pinnedPlacement: PinnedTodayPlacement {
        guard !visibleOffsets.isEmpty else { return .none }
        if visibleOffsets.contains(0) {
            return .none
        }

        if let maxVisibleOffset = visibleOffsets.max(), maxVisibleOffset < 0 {
            return .trailing
        }
        if let minVisibleOffset = visibleOffsets.min(), minVisibleOffset > 0 {
            return .leading
        }

        return .none
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                scrollTrack
                    .onAppear {
                        ensureSelectionVisible()
                        scrollToSelectedDate(with: proxy, animated: false)
                    }
                    .onChange(of: selectedDate) { _, _ in
                        ensureSelectionVisible()
                        scrollToSelectedDate(with: proxy, animated: true)
                    }
                    .onChange(of: isPresented) { _, presented in
                        guard presented else { return }
                        ensureSelectionVisible()
                        scrollToSelectedDate(with: proxy, animated: false)
                    }

                pinnedTodayOverlay(proxy: proxy)
            }
        }
        .frame(height: trackHeight)
    }

    private var scrollTrack: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: itemSpacing) {
                ForEach(dayOffsets, id: \.self) { offset in
                    let date = date(for: offset)
                    HStack(spacing: 6) {
                        if let marker = markerText(for: date) {
                            HomeDrawerCalendarMarkerLabel(text: marker)
                        }

                        Button {
                            guard !calendar.isDate(date, inSameDayAs: normalizedSelectedDate) else { return }
                            HapticFeedback.selection()
                            selectedDate = date
                        } label: {
                            HomeDrawerCalendarDayCell(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: normalizedSelectedDate),
                                isToday: calendar.isDate(date, inSameDayAs: today),
                                size: itemSize
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(width: itemSize, height: itemSize)
                        .opacity(offset == 0 && pinnedPlacement != .none ? 0 : 1)
                    }
                    .id(offset)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, horizontalInset)
        }
        .onScrollTargetVisibilityChange(idType: Int.self, threshold: 0.0) { identifiers in
            visibleOffsets = identifiers
            expandVisibleRangeIfNeeded(visibleOffsets: identifiers)
        }
    }

    @ViewBuilder
    private func pinnedTodayOverlay(proxy: ScrollViewProxy) -> some View {
        switch pinnedPlacement {
        case .leading:
            pinnedTodayButton(proxy: proxy, placement: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, horizontalInset)
        case .trailing:
            pinnedTodayButton(proxy: proxy, placement: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, horizontalInset)
        case .none:
            EmptyView()
        }
    }

    private func pinnedTodayButton(proxy: ScrollViewProxy, placement: PinnedTodayPlacement) -> some View {
        Button {
            HapticFeedback.selection()
            ensureSelectionVisible()
            if !calendar.isDate(today, inSameDayAs: normalizedSelectedDate) {
                selectedDate = today
            }
            scrollToSelectedDate(with: proxy, animated: true)
        } label: {
            if placement == .leading {
                Label("回到今日", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
            } else {
                Label("回到今日", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .tint(.accentColor)
    }

    private func ensureSelectionVisible() {
        let target = selectedOffset
        if target < visibleRange.lowerBound || target > visibleRange.upperBound {
            let lower = max(target - initialPastDays, -hardLimitDays)
            let upper = min(target + initialFutureDays, hardLimitDays)
            visibleRange = lower...upper
        }
    }

    private func expandVisibleRangeIfNeeded(visibleOffsets: [Int]) {
        guard let minVisibleOffset = visibleOffsets.min(),
              let maxVisibleOffset = visibleOffsets.max()
        else {
            return
        }

        var lower = visibleRange.lowerBound
        var upper = visibleRange.upperBound

        if minVisibleOffset <= visibleRange.lowerBound + 6, visibleRange.lowerBound > -hardLimitDays {
            lower = max(visibleRange.lowerBound - expansionBatch, -hardLimitDays)
        }
        if maxVisibleOffset >= visibleRange.upperBound - 6, visibleRange.upperBound < hardLimitDays {
            upper = min(visibleRange.upperBound + expansionBatch, hardLimitDays)
        }

        let nextRange = lower...upper
        guard nextRange != visibleRange else { return }
        visibleRange = nextRange
    }

    private func scrollToSelectedDate(with proxy: ScrollViewProxy, animated: Bool) {
        let target = selectedOffset
        guard visibleRange.contains(target) else { return }

        Task { @MainActor in
            if animated {
                withAnimation(.smooth(duration: 0.22)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            } else {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    private func date(for offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }

    private func markerText(for date: Date) -> String? {
        let day = calendar.component(.day, from: date)
        guard day == 1 else { return nil }

        let month = calendar.component(.month, from: date)
        if month == 1 {
            return localization.templateDateString(from: date, template: "yyyy")
        }

        return localization.templateDateString(from: date, template: "MMM")
    }
}

private enum PinnedTodayPlacement {
    case none
    case leading
    case trailing
}

private struct HomeDrawerCalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let size: CGFloat

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 2) {
            Text(date.formatted(.dateTime.weekday(.narrow)))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(labelColor.opacity(isSelected ? 0.75 : 0.82))

            Text(dayLabel)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(labelColor)
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isSelected ? 0 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var backgroundFill: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.96), Color.accentColor.opacity(0.80)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        if isToday {
            return AnyShapeStyle(Color.primary.opacity(0.08))
        }
        return AnyShapeStyle(Color.white.opacity(0.001))
    }

    private var borderColor: Color {
        if isToday {
            return Color.accentColor.opacity(0.34)
        }
        return Color.primary.opacity(0.10)
    }

    private var labelColor: Color {
        if isSelected {
            return .white
        }
        if isToday {
            return .accentColor
        }
        return .primary
    }

    private var dayLabel: String {
        String(calendar.component(.day, from: date))
    }
}

private struct HomeDrawerCalendarMarkerLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}
