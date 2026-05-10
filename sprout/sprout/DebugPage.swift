import SwiftUI

struct DebugPage: View {
    var body: some View {
        List {
            Section("语音测试") {
                NavigationLink(destination: SpeechRecognitionPage()) {
                    Label("语音转文字", systemImage: "mic.fill")
                }
            }

            Section("卡片预览") {
                ForEach(cardTypes, id: \.self) { name in
                    NavigationLink(destination: CardDebugView(cardType: name)) {
                        Label(name, systemImage: "rectangle.grid.2x2")
                    }
                }
            }

            Section("订阅") {
                NavigationLink(destination: SubscriptionDebugView()) {
                    Label("订阅状态与测试", systemImage: "creditcard")
                }
            }
        }
        .navigationTitle("Debug")
    }

    private let cardTypes = [
        "QuoteCard", "WeatherCard", "LinkCard", "ActivityCard",
        "MusicCard", "EmotionCard", "TodoCard", "PhotoCard",
    ]
}

struct CardDebugView: View {
    let cardType: String

    private var allSizes: [GridItem] {
        [
            GridItem(card: AnyView(cardView(for: "4x1")), columns: 4, units: 1),
            GridItem(card: AnyView(cardView(for: "4x2")), columns: 4, units: 2),
            GridItem(card: AnyView(cardView(for: "4x4")), columns: 4, units: 4),
        ]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                Text("4×1 · 4×2 · 4×4")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 12)

            CardGridView(items: allSizes)
                .padding(.vertical, 16)
        }
        .navigationTitle(cardType)
    }

    @ViewBuilder
    private func cardView(for size: String) -> some View {
        switch (cardType, size) {
        case ("QuoteCard",    "4x1"): QuoteCard_4x1()
        case ("QuoteCard",    "4x2"): QuoteCard_4x2()
        case ("QuoteCard",    "4x4"): QuoteCard_4x4()
        case ("WeatherCard",  "4x1"): WeatherCard_4x1()
        case ("WeatherCard",  "4x2"): WeatherCard_4x2()
        case ("WeatherCard",  "4x4"): WeatherCard_4x4()
        case ("LinkCard",     "4x1"): LinkCard_4x1()
        case ("LinkCard",     "4x2"): LinkCard_4x2()
        case ("LinkCard",     "4x4"): LinkCard_4x4()
        case ("ActivityCard", "4x1"): ActivityCard_4x1()
        case ("ActivityCard", "4x2"): ActivityCard_4x2()
        case ("ActivityCard", "4x4"): ActivityCard_4x4()
        case ("MusicCard",    "4x1"): MusicCard_4x1()
        case ("MusicCard",    "4x2"): MusicCard_4x2()
        case ("MusicCard",    "4x4"): MusicCard_4x4()
        case ("EmotionCard",  "4x1"): EmotionCard_4x1()
        case ("EmotionCard",  "4x2"): EmotionCard_4x2()
        case ("EmotionCard",  "4x4"): EmotionCard_4x4()
        case ("TodoCard",     "4x1"): TodoCard_4x1()
        case ("TodoCard",     "4x2"): TodoCard_4x2()
        case ("TodoCard",     "4x4"): TodoCard_4x4()
        case ("PhotoCard",    "4x1"): PhotoCard_4x1()
        case ("PhotoCard",    "4x2"): PhotoCard_4x2()
        case ("PhotoCard",    "4x4"): PhotoCard_4x4()
        default: EmptyView()
        }
    }
}

#Preview {
    NavigationStack {
        DebugPage()
    }
}
