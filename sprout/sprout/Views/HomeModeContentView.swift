import SwiftUI

struct HomeModeContentView: View {
    let displayMode: HomeDisplayMode
    let selectedDate: Date
    let insertionEdge: Edge

    var body: some View {
        ZStack {
            if displayMode == .dashboard {
                DailyView(date: selectedDate)
                    .id(selectedDate)
                    .transition(.asymmetric(
                        insertion: .move(edge: insertionEdge),
                        removal: .move(edge: insertionEdge == .leading ? .trailing : .leading)
                    ))
            }

            if displayMode == .rawRecords {
                RecordTimelineView(selectedDate: selectedDate)
                    .id("timeline-\(Calendar.current.startOfDay(for: selectedDate).timeIntervalSinceReferenceDate)")
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.28, bounce: 0.08), value: displayMode)
    }
}
