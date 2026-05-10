// ContentView.swift — 心泉 Today 主页
// 网格卡片布局 + 底部工具栏

import SwiftUI

struct ContentView: View {
    @State private var isShowingAccountSheet = false
    @State private var isShowingRecordSheet = false
    @State private var isShowingBottomSheet = true
    @State private var showFloatingInput = false
    @State private var inputText = ""

    var body: some View {
        ZStack(alignment: .top) {
            pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                CardGridView(items: gridItems)
                    .padding(.top, 60)
                    .padding(.bottom, 100)
            }

            TopNavigationBar(onProfileTapped: {
                isShowingAccountSheet = true
            })

            if showFloatingInput {
                VStack {
                    Spacer()
                    FloatingInputBar(
                        text: $inputText,
                        isShowingSheet: $isShowingBottomSheet,
                        onSend: {
                            print("发送: \(inputText)")
                            inputText = ""
                            showFloatingInput = false
                        },
                        onDismiss: {
                            inputText = ""
                            showFloatingInput = false
                        }
                    )
                    .padding(.bottom, 8)
                }
            }
        }
        .sheet(isPresented: $isShowingAccountSheet) {
            AccountManagementSheet()
        }
        .sheet(isPresented: $isShowingRecordSheet) {
            RecordSheet()
        }
        .sheet(isPresented: $isShowingBottomSheet) {
            BottomToolbarSheet(
                isShowing: $isShowingBottomSheet,
                onCameraTapped: {},
                onRecordTapped: {
                    isShowingBottomSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showFloatingInput = true
                    }
                },
                onAddTapped: {}
            )
        }
    }

    private var gridItems: [GridItem] {
        [
            GridItem(card: AnyView(QuoteCard_4x2()),    columns: 4, units: 2),
            GridItem(card: AnyView(WeatherCard_4x1()),  columns: 4, units: 1),
            GridItem(card: AnyView(LinkCard_4x1()),     columns: 4, units: 1),
            GridItem(card: AnyView(ActivityCard_4x2()), columns: 4, units: 2),
            GridItem(card: AnyView(MusicCard_4x2()),    columns: 4, units: 2),
            GridItem(card: AnyView(EmotionCard_4x1()),  columns: 4, units: 1),
            GridItem(card: AnyView(TodoCard_4x4()),     columns: 4, units: 4),
            GridItem(card: AnyView(PhotoCard_4x4()),    columns: 4, units: 4),
            GridItem(card: AnyView(QuoteCard_4x4()),    columns: 4, units: 4),
            GridItem(card: AnyView(WeatherCard_4x2()),  columns: 4, units: 2),
            GridItem(card: AnyView(MusicCard_4x4()),    columns: 4, units: 4),
            GridItem(card: AnyView(EmotionCard_4x2()),  columns: 4, units: 2),
        ]
    }
}

private let pageBackground = LinearGradient(
    stops: [
        .init(color: Color(red: 0.78, green: 0.91, blue: 0.97), location: 0.00),
        .init(color: Color(red: 0.88, green: 0.93, blue: 0.99), location: 0.45),
        .init(color: Color(red: 0.92, green: 0.96, blue: 0.92), location: 1.00),
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

#Preview {
    ContentView()
}