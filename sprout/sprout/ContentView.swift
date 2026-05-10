// ContentView.swift — 心泉 Today 主页
// 网格卡片布局 + 底部工具栏

import SwiftUI
import SwiftData
import MapKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Record.createdAt, order: .reverse) private var records: [Record]

    @State private var isShowingAccountSheet = false
    @State private var isBarOpen = false
    @Environment(\.colorScheme) private var colorScheme

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    CardGridView(items: gridItems)
                        .padding(.top, 24)
                        .padding(.bottom, 96)
                }

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
                    Menu {
                        Button { } label: {
                            Label("看板", systemImage: "square.grid.2x2")
                        }
                        Button { } label: {
                            Label("日历", systemImage: "calendar")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("今日")
                                .font(.body)
                                .foregroundColor(.primary)
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
        }
        .sheet(isPresented: $isShowingAccountSheet) {
            AccountManagementSheet()
        }
    }

    // MARK: Grid items

    /// Maps persisted Records to dashboard cards via RecordMapper.
    /// Falls back to static placeholder cards when the database is empty.
    private var gridItems: [GridItem] {
        if records.isEmpty {
            return placeholderItems
        }
        return records
            .flatMap { RecordMapper.allCards(record: $0) }
            .map { info in
                GridItem(
                    card: AnyView(
                        NavigationLink(
                            destination: RecordDetailView(
                                record: info.record,
                                focusedSection: info.focusedSection
                            )
                        ) {
                            info.cardView
                        }
                        .buttonStyle(.plain)
                    ),
                    columns: info.columns,
                    units: info.units
                )
            }
    }

    // MARK: Record creation

    private func insertRecord(body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let record = Record()
        record.body = trimmed

        // Detect special content in the text
        let parsed = RecordParser.parseBody(trimmed)
        record.cardType = RecordParser.primaryCardType(body: trimmed, parsed: parsed)

        // Create MediaCard entries for detected links
        var mediaCards: [MediaCard] = []

        for url in parsed.appleMusicURLs {
            let m = MediaCard()
            m.type = "music"
            m.url = url.absoluteString
            m.title = url.lastPathComponent.replacingOccurrences(of: "-", with: " ")
            mediaCards.append(m)
            modelContext.insert(m)
        }

        for url in parsed.regularURLs {
            let m = MediaCard()
            m.type = "link"
            m.url = url.absoluteString
            m.title = url.host ?? url.absoluteString
            mediaCards.append(m)
            modelContext.insert(m)
        }

        modelContext.insert(record)

        // Associate media cards after insertion (SwiftData requires objects to exist first)
        if !mediaCards.isEmpty {
            record.mediaCards = mediaCards
        }
    }

    // MARK: Placeholder (shown when no records exist)

    private var placeholderItems: [GridItem] {
        [
            GridItem(card: AnyView(QuoteCard_4x2()),    columns: 4, units: 2),
            GridItem(card: AnyView(WeatherCard_4x1()),  columns: 4, units: 1),
            GridItem(card: AnyView(LinkCard_4x2()),     columns: 4, units: 2),
            GridItem(card: AnyView(ActivityCard_4x2()), columns: 4, units: 2),
            GridItem(card: AnyView(MusicCard_4x2()),    columns: 4, units: 2),
            GridItem(card: AnyView(EmotionCard_4x1()),  columns: 4, units: 1),
            GridItem(card: AnyView(TodoCard_4x4()),     columns: 4, units: 4),
            GridItem(card: AnyView(PhotoCard_4x4()),    columns: 4, units: 4),
        ]
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

#Preview {
    ContentView()
        .modelContainer(for: [Record.self, MediaCard.self, Activity.self], inMemory: true)
}
