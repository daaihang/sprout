import SwiftUI

struct HomeCardsSwiftUIPager: View {
    @Binding var selectedDate: Date
    let topContentInset: CGFloat

    @State private var visibleDates: [Date] = []
    @State private var scrollPositionID: Date?
    @State private var isSyncingFromExternalSelection = false

    private let calendar = Calendar.current
    private let anchorDate = Calendar.current.date(from: DateComponents(year: 1970, month: 1, day: 1))
        ?? Calendar.current.startOfDay(for: Date())
    private let leadingBufferDays = 7
    private let trailingBufferDays = 7
    private let rebuildThreshold = 2

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(visibleDates, id: \.self) { date in
                        HomeCardsSwiftUIPage(date: date, topContentInset: topContentInset)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .containerRelativeFrame(.horizontal)
                            .id(date)
                    }
                }
                .scrollTargetLayout()
            }
            .coordinateSpace(name: "homeScrollArea")
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPositionID)
            .onAppear {
                let initialDate = clamped(date: selectedDate)
                let initialWindow = windowDates(centeredOn: initialDate)
                visibleDates = initialWindow
                scrollPositionID = initialDate
            }
            .onChange(of: selectedDate) { _, newDate in
                syncToExternalSelection(newDate)
            }
            .onChange(of: scrollPositionID) { _, newPosition in
                handleScrollPositionChange(newPosition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .ignoresSafeArea(.container, edges: [.top, .bottom])
    }

    private func syncToExternalSelection(_ newDate: Date) {
        let targetDate = clamped(date: newDate)
        ensureWindowContains(targetDate)

        guard !calendar.isDate(targetDate, inSameDayAs: scrollPositionID ?? anchorDate) else { return }
        isSyncingFromExternalSelection = true
        withAnimation(.smooth(duration: 0.24)) {
            scrollPositionID = targetDate
        }
    }

    private func handleScrollPositionChange(_ newPosition: Date?) {
        guard let newPosition else { return }

        ensureWindowContains(newPosition)

        if !calendar.isDate(newPosition, inSameDayAs: selectedDate) {
            HapticFeedback.selection()
            selectedDate = newPosition
        }

        if isSyncingFromExternalSelection,
           calendar.isDate(newPosition, inSameDayAs: selectedDate) {
            isSyncingFromExternalSelection = false
        }
    }

    private func ensureWindowContains(_ date: Date) {
        let normalized = clamped(date: date)
        guard !visibleDates.isEmpty else {
            visibleDates = windowDates(centeredOn: normalized)
            return
        }

        guard let currentIndex = visibleDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: normalized) }) else {
            visibleDates = windowDates(centeredOn: normalized)
            return
        }

        let lowerThreshold = rebuildThreshold
        let upperThreshold = max(visibleDates.count - rebuildThreshold - 1, 0)
        guard currentIndex <= lowerThreshold || currentIndex >= upperThreshold else { return }

        let updatedWindow = windowDates(centeredOn: normalized)
        guard updatedWindow != visibleDates else { return }
        visibleDates = updatedWindow
    }

    private func windowDates(centeredOn centerDate: Date) -> [Date] {
        let normalizedCenter = clamped(date: centerDate)
        let startOffset = max(-leadingBufferDays, daysFromAnchor(to: normalizedCenter) * -1)

        return (startOffset...trailingBufferDays).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: normalizedCenter).map(clamped(date:))
        }
    }

    private func daysFromAnchor(to date: Date) -> Int {
        calendar.dateComponents([.day], from: anchorDate, to: clamped(date: date)).day ?? 0
    }

    private func clamped(date: Date) -> Date {
        let normalized = calendar.startOfDay(for: date)
        return max(normalized, anchorDate)
    }
}

private struct HomeCardsSwiftUIPage: View {
    let date: Date
    let topContentInset: CGFloat

    var body: some View {
        DailyView(date: date, topContentInset: topContentInset)
            .id(date)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: [.top, .bottom])
    }
}
