// ContentView.swift — 心泉 Today 主页
// 网格卡片布局 + 底部工具栏

import SwiftUI
import MapKit

struct ContentView: View {
    @State private var isShowingAccountSheet = false
    @State private var isBarOpen = false
    @Environment(\.colorScheme) private var colorScheme

    private var onProfileTapped: () -> Void {
        { isShowingAccountSheet = true }
    }

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
                    onSend: { text in print("发送: \(text)") }
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                        } label: {
                            Label("看板", systemImage: "square.grid.2x2")
                        }

                        Button {
                        } label: {
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
                    Button(action: onProfileTapped) {
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

    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 · EEEE"
        return formatter.string(from: Date())
    }

    private var gridItems: [GridItem] {
        [
            GridItem(card: AnyView(QuoteCard_4x2()),    columns: 4, units: 2),
            GridItem(card: AnyView(WeatherCard_4x1()),  columns: 4, units: 1),
            GridItem(card: AnyView(LinkCard_4x2()),     columns: 4, units: 2),
            GridItem(card: AnyView(ActivityCard_4x2()), columns: 4, units: 2),
            GridItem(card: AnyView(MusicCard_4x2()),    columns: 4, units: 2),
            GridItem(card: AnyView(EmotionCard_4x1()),  columns: 4, units: 1),
            GridItem(card: AnyView(TodoCard_4x4()),     columns: 4, units: 4),
            GridItem(card: AnyView(PhotoCard_4x4()),    columns: 4, units: 4),
            GridItem(card: AnyView(QuoteCard_4x4()),    columns: 4, units: 4),
            GridItem(card: AnyView(WeatherCard_4x2()),  columns: 4, units: 2),
            GridItem(card: AnyView(MusicCard_4x4()),    columns: 4, units: 4),
            GridItem(card: AnyView(EmotionCard_4x2()),  columns: 4, units: 2),
            GridItem(card: AnyView(MapCard_4x4(data: previewMapData)), columns: 4, units: 4),
        ]
    }

    private var previewMapData: MapCardData {
        MapCardData(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            locationName: "San Francisco",
            descriptionText: "Test location"
        )
    }

    private var pageBackground: LinearGradient {
        if colorScheme == .dark {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.08, green: 0.10, blue: 0.16), location: 0.00),
                    .init(color: Color(red: 0.10, green: 0.11, blue: 0.18), location: 0.45),
                    .init(color: Color(red: 0.08, green: 0.12, blue: 0.10), location: 1.00),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.78, green: 0.91, blue: 0.97), location: 0.00),
                    .init(color: Color(red: 0.88, green: 0.93, blue: 0.99), location: 0.45),
                    .init(color: Color(red: 0.92, green: 0.96, blue: 0.92), location: 1.00),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

#Preview {
    ContentView()
}
