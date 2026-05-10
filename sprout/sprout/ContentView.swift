// ContentView.swift — 心泉 Today 主页
// 日期导航 + 每日卡片网格 + 底部工具栏

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isShowingAccountSheet = false
    @State private var isBarOpen = false
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showDatePicker = false
    @State private var insertionEdge: Edge = .trailing   // tracks swipe direction for transition
    @Environment(\.colorScheme) private var colorScheme

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                pageBackground.ignoresSafeArea()

                // Daily card grid — re-created when selectedDate changes
                DailyView(date: selectedDate)
                    .id(selectedDate)
                    .transition(.asymmetric(
                        insertion: .move(edge: insertionEdge),
                        removal:   .move(edge: insertionEdge == .leading ? .trailing : .leading)
                    ))

                BottomCapsuleBar(
                    isOpen: $isBarOpen,
                    onCameraTapped: {},
                    onAddTapped: {},
                    onSend: { text in insertRecord(body: text) }
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showDatePicker.toggle() } label: {
                        HStack(spacing: 4) {
                            Text(formattedDateLabel(selectedDate))
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                                .contentTransition(.numericText())
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isShowingAccountSheet = true } label: {
                        Image(systemName: "person")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            // Swipe left/right to change date
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        if value.translation.width < -40 {
                            navigateDay(by: -1)   // swipe left → previous day
                        } else if value.translation.width > 40 {
                            navigateDay(by: +1)   // swipe right → next day
                        }
                    }
            )
        }
        .animation(.spring(duration: 0.35, bounce: 0.1), value: selectedDate)
        .sheet(isPresented: $isShowingAccountSheet) { AccountManagementSheet() }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
                .presentationDetents([.medium])
        }
    }

    // MARK: Date navigation

    private func navigateDay(by delta: Int) {
        let cal  = Calendar.current
        let next = cal.date(byAdding: .day, value: delta, to: selectedDate)!
        let today = cal.startOfDay(for: Date())
        guard next <= today else { return }

        // delta < 0 = going to earlier date → new view comes from the LEFT (past is on the left)
        insertionEdge = delta < 0 ? .leading : .trailing
        withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
            selectedDate = next
        }
    }

    private func formattedDateLabel(_ date: Date) -> String {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        if cal.isDate(date, inSameDayAs: today) { return "今日" }
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        if cal.isDate(date, inSameDayAs: yesterday) { return "昨天" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 · EEE"
        return f.string(from: date)
    }

    // MARK: Record creation

    private func insertRecord(body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let record = Record()
        record.body = trimmed

        // Assign createdAt to the selected date
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        if cal.isDate(selectedDate, inSameDayAs: today) {
            // Today: use the actual current time
            record.createdAt = Date()
        } else {
            // Past day: place at end of that day so it sorts near top
            let dayEnd = cal.date(byAdding: .day, value: 1, to: selectedDate)!
            record.createdAt = dayEnd.addingTimeInterval(-1)
        }
        record.updatedAt = record.createdAt

        let parsed = RecordParser.parseBody(trimmed)
        record.cardType = RecordParser.primaryCardType(body: trimmed, parsed: parsed)

        var mediaCards: [MediaCard] = []
        for url in parsed.appleMusicURLs {
            let m = MediaCard(); m.type = "music"
            m.url = url.absoluteString
            m.title = url.lastPathComponent.replacingOccurrences(of: "-", with: " ")
            mediaCards.append(m); modelContext.insert(m)
        }
        for url in parsed.regularURLs {
            let m = MediaCard(); m.type = "link"
            m.url = url.absoluteString
            m.title = url.host ?? url.absoluteString
            mediaCards.append(m); modelContext.insert(m)
        }
        modelContext.insert(record)
        if !mediaCards.isEmpty { record.mediaCards = mediaCards }
    }

    // MARK: Background

    private var pageBackground: LinearGradient {
        if colorScheme == .dark {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.08, green: 0.10, blue: 0.16), location: 0.00),
                    .init(color: Color(red: 0.10, green: 0.11, blue: 0.18), location: 0.45),
                    .init(color: Color(red: 0.08, green: 0.12, blue: 0.10), location: 1.00),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.78, green: 0.91, blue: 0.97), location: 0.00),
                    .init(color: Color(red: 0.88, green: 0.93, blue: 0.99), location: 0.45),
                    .init(color: Color(red: 0.92, green: 0.96, blue: 0.92), location: 1.00),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - DatePickerSheet

private struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "选择日期",
                    selection: $selectedDate,
                    in: ...Calendar.current.startOfDay(for: Date()),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .onChange(of: selectedDate) { _, new in
                    // Normalise to start-of-day so DailyView query stays clean
                    let norm = Calendar.current.startOfDay(for: new)
                    if norm != selectedDate { selectedDate = norm }
                }
            }
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [Record.self, MediaCard.self, Activity.self], inMemory: true)
}
