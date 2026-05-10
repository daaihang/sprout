import SwiftUI
import PhotosUI
import MapKit
import MusicKit

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
        "MusicCard", "EmotionCard", "TodoCard", "PhotoCard", "MapCard",
    ]
}

struct CardDebugView: View {
    let cardType: String

    @State private var debugData: PhotoCardData = PhotoCardData()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isLoadingImages = false

    @State private var mapData: MapCardData = MapCardData()
    @State private var showMapSheet = false

    @State private var linkData: LinkCardData = LinkCardData()
    @State private var newLinkURL: String = ""
    @State private var newLinkTitle: String = ""
    @State private var newLinkDescription: String = ""

    @State private var musicData: MusicCardData = MusicCardData()
    @State private var showMusicSheet = false
    @State private var musicService = MusicService()

    @State private var quoteData = QuoteCardData()
    @State private var weatherData = WeatherCardData()
    @State private var activityData = ActivityCardData()
    @State private var emotionData: EmotionCardData? = nil
    @State private var todoData = TodoCardData()
    @State private var newTodoText = ""

    private var photoCardSizes: [GridItem] {
        [
            GridItem(card: AnyView(PhotoCard_4x2(data: debugData)), columns: 4, units: 2),
            GridItem(card: AnyView(PhotoCard_4x4(data: debugData)), columns: 4, units: 4),
        ]
    }

    private var mapCardSizes: [GridItem] {
        [
            GridItem(card: AnyView(MapCard_4x2(data: mapData, onTap: { showMapSheet = true })), columns: 4, units: 2),
            GridItem(card: AnyView(MapCard_4x4(data: mapData, onTap: { showMapSheet = true })), columns: 4, units: 4),
        ]
    }

    private var linkCardSizes: [GridItem] {
        [
            GridItem(card: AnyView(LinkCard_4x2(data: linkData)), columns: 4, units: 2),
            GridItem(card: AnyView(LinkCard_4x4(data: linkData)), columns: 4, units: 4),
        ]
    }

    private var musicCardSizes: [GridItem] {
        [
            GridItem(card: AnyView(MusicCard_4x1(data: musicData.isEmpty ? nil : musicData, onTap: { showMusicSheet = true })), columns: 4, units: 1),
            GridItem(card: AnyView(MusicCard_4x2(data: musicData.isEmpty ? nil : musicData, onTap: { showMusicSheet = true })), columns: 4, units: 2),
            GridItem(card: AnyView(MusicCard_4x4(data: musicData.isEmpty ? nil : musicData, onTap: { showMusicSheet = true })), columns: 4, units: 4),
        ]
    }

    private var quoteCardSizes: [GridItem] {
        let d: QuoteCardData? = quoteData.isEmpty ? nil : quoteData
        return [
            GridItem(card: AnyView(QuoteCard_4x1(data: d)), columns: 4, units: 1),
            GridItem(card: AnyView(QuoteCard_4x2(data: d)), columns: 4, units: 2),
            GridItem(card: AnyView(QuoteCard_4x4(data: d)), columns: 4, units: 4),
        ]
    }

    private var weatherCardSizes: [GridItem] {
        let d: WeatherCardData? = weatherData.isEmpty ? nil : weatherData
        return [
            GridItem(card: AnyView(WeatherCard_4x1(data: d)), columns: 4, units: 1),
            GridItem(card: AnyView(WeatherCard_4x2(data: d)), columns: 4, units: 2),
            GridItem(card: AnyView(WeatherCard_4x4(data: d)), columns: 4, units: 4),
        ]
    }

    private var activityCardSizes: [GridItem] {
        let d: ActivityCardData? = activityData.isEmpty ? nil : activityData
        return [
            GridItem(card: AnyView(ActivityCard_4x1(data: d)), columns: 4, units: 1),
            GridItem(card: AnyView(ActivityCard_4x2(data: d)), columns: 4, units: 2),
            GridItem(card: AnyView(ActivityCard_4x4(data: d)), columns: 4, units: 4),
        ]
    }

    private var emotionCardSizes: [GridItem] {
        [
            GridItem(card: AnyView(EmotionCard_4x1(data: emotionData)), columns: 4, units: 1),
            GridItem(card: AnyView(EmotionCard_4x2(data: emotionData)), columns: 4, units: 2),
            GridItem(card: AnyView(EmotionCard_4x4(data: emotionData)), columns: 4, units: 4),
        ]
    }

    private var todoCardSizes: [GridItem] {
        let d: TodoCardData? = todoData.isEmpty ? nil : todoData
        return [
            GridItem(card: AnyView(TodoCard_4x1(data: d)), columns: 4, units: 1),
            GridItem(card: AnyView(TodoCard_4x2(data: d)), columns: 4, units: 2),
            GridItem(card: AnyView(TodoCard_4x4(data: d)), columns: 4, units: 4),
        ]
    }

    private var otherCardSizes: [GridItem] {
        [
            GridItem(card: AnyView(cardView(for: "4x1")), columns: 4, units: 1),
            GridItem(card: AnyView(cardView(for: "4x2")), columns: 4, units: 2),
            GridItem(card: AnyView(cardView(for: "4x4")), columns: 4, units: 4),
        ]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                Text(cardType == "PhotoCard" || cardType == "MapCard" || cardType == "LinkCard" ? "4×2 · 4×4" : "4×1 · 4×2 · 4×4")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 12)

            let items: [GridItem] = {
                switch cardType {
                case "PhotoCard": return photoCardSizes
                case "MapCard": return mapCardSizes
                case "LinkCard": return linkCardSizes
                case "MusicCard":    return musicCardSizes
                case "QuoteCard":   return quoteCardSizes
                case "WeatherCard": return weatherCardSizes
                case "ActivityCard":return activityCardSizes
                case "EmotionCard": return emotionCardSizes
                case "TodoCard":    return todoCardSizes
                default: return otherCardSizes
                }
            }()
            CardGridView(items: items)
                .padding(.vertical, 16)

            if cardType == "PhotoCard" {
                debugControlsSection
            } else if cardType == "MapCard" {
                mapDebugControlsSection
            } else if cardType == "LinkCard" {
                linkDebugControlsSection
            } else if cardType == "MusicCard" {
                musicDebugControlsSection
            } else if cardType == "QuoteCard" {
                quoteDebugControlsSection
            } else if cardType == "WeatherCard" {
                weatherDebugControlsSection
            } else if cardType == "ActivityCard" {
                activityDebugControlsSection
            } else if cardType == "EmotionCard" {
                emotionDebugControlsSection
            } else if cardType == "TodoCard" {
                todoDebugControlsSection
            }
        }
        .navigationTitle(cardType)
        .sheet(isPresented: $showMapSheet) {
            MapCardSheet(data: $mapData)
        }
        .sheet(isPresented: $showMusicSheet) {
            MusicCardSheet(data: $musicData, musicService: musicService)
        }
    }

    @ViewBuilder
    private var debugControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("调试控件")
                .font(.headline)
                .padding(.horizontal, 16)

            VStack(spacing: 12) {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Label(selectedItems.isEmpty ? "选择照片" : "已选择 \(selectedItems.count) 张照片", systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .onChange(of: selectedItems) { _, newItems in
                    loadImages(from: newItems)
                }

                TextField("地点名称", text: $debugData.locationName)
                    .textFieldStyle(.roundedBorder)

                TextField("描述文字", text: $debugData.descriptionText)
                    .textFieldStyle(.roundedBorder)

                Button("清除数据") {
                    selectedItems = []
                    debugData = PhotoCardData()
                }
                .foregroundColor(.red)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private var mapDebugControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("调试控件")
                .font(.headline)
                .padding(.horizontal, 16)

            VStack(spacing: 12) {
                Button {
                    showMapSheet = true
                } label: {
                    Label("编辑地点", systemImage: "map")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                TextField("地点名称", text: $mapData.locationName)
                    .textFieldStyle(.roundedBorder)

                TextField("描述文字", text: $mapData.descriptionText)
                    .textFieldStyle(.roundedBorder)

                Button("清除数据") {
                    mapData = MapCardData()
                }
                .foregroundColor(.red)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private var linkDebugControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("调试控件")
                .font(.headline)
                .padding(.horizontal, 16)

            VStack(spacing: 12) {
                TextField("URL", text: $newLinkURL)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)

                TextField("标题", text: $newLinkTitle)
                    .textFieldStyle(.roundedBorder)

                TextField("描述", text: $newLinkDescription)
                    .textFieldStyle(.roundedBorder)

                Button {
                    if let url = URL(string: newLinkURL), !newLinkURL.isEmpty {
                        var item = LinkItem(url: url, title: newLinkTitle, description: newLinkDescription)
                        fetchFavicon(for: item) { image in
                            if let image = image {
                                item.iconImage = image
                            }
                            DispatchQueue.main.async {
                                withAnimation {
                                    linkData.links.append(item)
                                }
                            }
                        }
                        newLinkURL = ""
                        newLinkTitle = ""
                        newLinkDescription = ""
                    }
                } label: {
                    Label("添加链接", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(newLinkURL.isEmpty)

                if !linkData.links.isEmpty {
                    ForEach(linkData.links) { link in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(link.title.isEmpty ? link.domain : link.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(link.domain)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button {
                                withAnimation {
                                    linkData.links.removeAll { $0.id == link.id }
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .transition(.asymmetric(insertion: .slide, removal: .opacity))
                }

                Button("清除数据") {
                    linkData = LinkCardData()
                    newLinkURL = ""
                    newLinkTitle = ""
                    newLinkDescription = ""
                }
                .foregroundColor(.red)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    private func fetchFavicon(for item: LinkItem, completion: @escaping (UIImage?) -> Void) {
        guard let iconURL = item.iconURL else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: iconURL) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                completion(image)
            } else {
                completion(nil)
            }
        }.resume()
    }

    private func loadImages(from items: [PhotosPickerItem]) {
        guard !items.isEmpty else {
            debugData.images = []
            return
        }

        isLoadingImages = true
        Task {
            var loadedImages: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loadedImages.append(image)
                }
            }
            await MainActor.run {
                debugData.images = loadedImages
                isLoadingImages = false
            }
        }
    }

    @ViewBuilder
    private func cardView(for size: String) -> some View {
        switch (cardType, size) {
        default: EmptyView()
        }
    }

    @ViewBuilder
    private var musicDebugControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("调试控件")
                .font(.headline)
                .padding(.horizontal, 16)

            VStack(spacing: 12) {
                HStack {
                    Label(musicAuthStatusText, systemImage: musicAuthStatusIcon)
                        .foregroundColor(musicAuthStatusColor)
                        .font(.subheadline)
                    Spacer()
                    if musicService.authorizationStatus == .notDetermined {
                        Button("请求权限") {
                            Task { await musicService.requestAuthorization() }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    } else if musicService.authorizationStatus == .denied {
                        Button("打开设置") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 16)

                Divider().padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("正在播放")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)

                    if let nowPlaying = musicService.nowPlayingData {
                        HStack(spacing: 12) {
                            Group {
                                if let artwork = nowPlaying.albumArtwork {
                                    Image(uiImage: artwork)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Color.gray.opacity(0.2)
                                        .overlay(Image(systemName: "music.note").foregroundColor(.secondary))
                                }
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(nowPlaying.trackName)
                                    .font(.subheadline).fontWeight(.medium)
                                    .lineLimit(1)
                                Text(nowPlaying.artistName)
                                    .font(.caption).foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button {
                                withAnimation { musicData = nowPlaying }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal, 16)
                    } else {
                        HStack {
                            Image(systemName: "music.note.slash").foregroundColor(.secondary)
                            Text("暂无正在播放的音乐")
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                    }
                }

                Divider().padding(.horizontal, 16)

                Button {
                    showMusicSheet = true
                } label: {
                    Label("搜索并添加音乐", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)

                Button {
                    Task { await musicService.refreshNowPlaying() }
                } label: {
                    Label("刷新正在播放", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)
                .disabled(musicService.authorizationStatus != .authorized)

                if !musicData.isEmpty {
                    Button("清除数据") {
                        withAnimation { musicData = MusicCardData() }
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Quote Debug

    @ViewBuilder
    private var quoteDebugControlsSection: some View {
        let presets: [(String, String)] = [
            ("不积跬步，无以至千里；不积小流，无以成江海。", "荀子"),
            ("纸上得来终觉浅，绝知此事要躬行。", "陆游"),
            ("宝剑锋从磨砺出，梅花香自苦寒来。", ""),
            ("苟利国家生死以，岂因祸福避趋之。", "林则徐"),
        ]
        VStack(alignment: .leading, spacing: 16) {
            Text("调试控件").font(.headline).padding(.horizontal, 16)
            VStack(spacing: 12) {
                TextEditor(text: $quoteData.quote)
                    .frame(height: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        Group {
                            if quoteData.quote.isEmpty {
                                Text("语录内容").foregroundStyle(.secondary).padding(12)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .allowsHitTesting(false)
                            }
                        }
                    )
                TextField("作者", text: $quoteData.author).textFieldStyle(.roundedBorder)
                TextField("出处（如《论语》）", text: $quoteData.source).textFieldStyle(.roundedBorder)
                Text("预设语录").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: [SwiftUI.GridItem(.flexible()), SwiftUI.GridItem(.flexible())], spacing: 8) {
                    ForEach(presets, id: \.0) { quote, author in
                        Button {
                            quoteData.quote = quote
                            quoteData.author = author
                        } label: {
                            Text(quote)
                                .font(.system(size: 10))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.accentColor.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .foregroundStyle(.primary)
                    }
                }
                if !quoteData.isEmpty {
                    Button("清除数据") { quoteData = QuoteCardData() }.foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
    }

    // MARK: - Weather Debug

    @ViewBuilder
    private var weatherDebugControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("调试控件").font(.headline).padding(.horizontal, 16)
            VStack(spacing: 12) {
                TextField("城市名称", text: $weatherData.location).textFieldStyle(.roundedBorder)
                HStack {
                    Text("温度")
                    Spacer()
                    Stepper("\(Int(weatherData.temperature))°C", value: $weatherData.temperature, in: -40...50)
                }
                HStack {
                    Text("体感温度")
                    Spacer()
                    Stepper("\(Int(weatherData.feelsLike))°C", value: $weatherData.feelsLike, in: -40...50)
                }
                HStack {
                    Text("最高 / 最低")
                    Spacer()
                    Stepper("H:\(Int(weatherData.high))°", value: $weatherData.high, in: -40...50)
                    Stepper("L:\(Int(weatherData.low))°", value: $weatherData.low, in: -40...50)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("湿度 \(weatherData.humidity)%").font(.caption).foregroundStyle(.secondary)
                    Slider(value: Binding(get: { Double(weatherData.humidity) }, set: { weatherData.humidity = Int($0) }), in: 0...100, step: 5)
                }
                Text("天气状况").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: Array(repeating: SwiftUI.GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(WeatherCondition.allCases, id: \.self) { condition in
                        Button {
                            weatherData.condition = condition
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: condition.sfSymbol)
                                    .font(.system(size: 20))
                                    .foregroundStyle(condition.color)
                                    .symbolRenderingMode(.multicolor)
                                Text(condition.label).font(.system(size: 9)).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(weatherData.condition == condition ? Color.accentColor.opacity(0.12) : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .foregroundStyle(.primary)
                    }
                }
                if !weatherData.isEmpty {
                    Button("清除数据") { weatherData = WeatherCardData() }.foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
    }

    // MARK: - Activity Debug

    @ViewBuilder
    private var activityDebugControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("调试控件").font(.headline).padding(.horizontal, 16)
            VStack(spacing: 12) {
                Text("运动类型").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: Array(repeating: SwiftUI.GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(ActivityType.allCases, id: \.self) { type in
                        Button {
                            activityData.type = type
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.sfSymbol)
                                    .font(.system(size: 18))
                                    .foregroundStyle(type.color)
                                Text(type.label).font(.system(size: 9)).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(activityData.type == type ? Color.accentColor.opacity(0.12) : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .foregroundStyle(.primary)
                    }
                }
                HStack {
                    Text("数值")
                    Spacer()
                    Stepper("\(activityData.formattedValue) \(activityData.type.defaultUnit)", value: $activityData.value, in: 0...50000, step: activityData.type == .steps ? 500 : 0.5)
                }
                HStack {
                    Text("目标")
                    Spacer()
                    Stepper(activityData.goal > 0 ? "\(activityData.goal.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", activityData.goal) : String(format: "%.1f", activityData.goal))" : "不设目标", value: $activityData.goal, in: 0...50000, step: activityData.type == .steps ? 1000 : 1)
                }
                HStack {
                    Text("时长")
                    Spacer()
                    Stepper(activityData.durationMinutes > 0 ? "\(activityData.durationMinutes) min" : "不记录", value: $activityData.durationMinutes, in: 0...300, step: 5)
                }
                HStack(spacing: 8) {
                    ForEach([
                        ("步数 8500", { activityData = ActivityCardData(type: .steps, value: 8500, goal: 10000) }),
                        ("跑步 5km", { activityData = ActivityCardData(type: .running, value: 5.2, goal: 5, durationMinutes: 32) }),
                        ("睡眠 7.5h", { activityData = ActivityCardData(type: .sleep, value: 7.5, goal: 8, durationMinutes: 450) }),
                    ], id: \.0) { label, action in
                        Button(label) { action() }
                            .font(.caption)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                if !activityData.isEmpty {
                    Button("清除数据") { activityData = ActivityCardData() }.foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
    }

    // MARK: - Emotion Debug

    @ViewBuilder
    private var emotionDebugControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("调试控件").font(.headline).padding(.horizontal, 16)
            VStack(spacing: 12) {
                Text("选择心情").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: Array(repeating: SwiftUI.GridItem(.flexible()), count: 3), spacing: 10) {
                    ForEach(MoodType.allCases, id: \.self) { mood in
                        Button {
                            if emotionData == nil { emotionData = EmotionCardData() }
                            emotionData?.mood = mood
                        } label: {
                            VStack(spacing: 4) {
                                Text(mood.emoji).font(.system(size: 26))
                                Text(mood.label).font(.system(size: 10))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(emotionData?.mood == mood ? mood.color.opacity(0.15) : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(emotionData?.mood == mood ? mood.color.opacity(0.4) : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .foregroundStyle(.primary)
                    }
                }
                if emotionData != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("强度 \(emotionData?.intensity ?? 3)/5").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { i in
                                Button {
                                    emotionData?.intensity = i
                                } label: {
                                    Circle()
                                        .fill((emotionData?.intensity ?? 0) >= i ? (emotionData?.mood.color ?? .accentColor) : Color(.systemGray4))
                                        .frame(width: 28, height: 28)
                                }
                            }
                            Spacer()
                        }
                    }
                    TextField("备注（可选）", text: Binding(
                        get: { emotionData?.note ?? "" },
                        set: { emotionData?.note = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    Button("清除数据") { emotionData = nil }.foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
    }

    // MARK: - Todo Debug

    @ViewBuilder
    private var todoDebugControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("调试控件").font(.headline).padding(.horizontal, 16)
            VStack(spacing: 12) {
                TextField("清单标题（可选）", text: $todoData.title).textFieldStyle(.roundedBorder)
                HStack(spacing: 8) {
                    TextField("添加事项", text: $newTodoText)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit { addTodoItem() }
                    Button("添加") { addTodoItem() }
                        .disabled(newTodoText.isEmpty)
                }
                if !todoData.items.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(todoData.items) { item in
                            HStack(spacing: 10) {
                                Button {
                                    if let idx = todoData.items.firstIndex(where: { $0.id == item.id }) {
                                        todoData.items[idx].isDone.toggle()
                                    }
                                } label: {
                                    Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(item.isDone ? .green : .secondary)
                                }
                                Text(item.text)
                                    .font(.system(size: 14))
                                    .strikethrough(item.isDone)
                                    .foregroundStyle(item.isDone ? .secondary : .primary)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    todoData.items.removeAll { $0.id == item.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                            Divider()
                        }
                    }
                    .padding(.horizontal, 4)
                    Text("\(todoData.doneCount)/\(todoData.totalCount) 已完成")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Button("清除数据") {
                        todoData = TodoCardData()
                        newTodoText = ""
                    }.foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
    }

    private func addTodoItem() {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation { todoData.items.append(TodoItem(text: trimmed)) }
        newTodoText = ""
    }

    // MARK: - Music Auth Helpers

    private var musicAuthStatusText: String {
        switch musicService.authorizationStatus {
        case .authorized: return "MusicKit 已授权"
        case .denied: return "MusicKit 已拒绝"
        case .notDetermined: return "MusicKit 未授权"
        case .restricted: return "MusicKit 受限"
        @unknown default: return "MusicKit 未知状态"
        }
    }

    private var musicAuthStatusIcon: String {
        switch musicService.authorizationStatus {
        case .authorized: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private var musicAuthStatusColor: Color {
        switch musicService.authorizationStatus {
        case .authorized: return .green
        case .denied: return .red
        default: return .orange
        }
    }
}

#Preview {
    NavigationStack {
        DebugPage()
    }
}
