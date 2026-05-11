import SwiftUI
import PhotosUI
import MapKit
import MusicKit
import SwiftData

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
        "AudioCard", "PeopleCard", "TodayInHistoryCard",
        "BookCard", "FilmCard",
    ]
}

struct CardDebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DashboardSystemCardConfig.dashboardOrder, order: .forward) private var systemConfigs: [DashboardSystemCardConfig]
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
    @State private var weatherService = WeatherDataService()
    @State private var isFetchingWeather = false
    @State private var activityData = ActivityCardData()
    @State private var emotionData: EmotionCardData? = nil
    @State private var todoData = TodoCardData()
    @State private var newTodoText = ""
    @State private var bookData = BookCardData()
    @State private var filmData = FilmCardData()
    @State private var audioData = AudioCardData(
        title: "晨间散步录音",
        audioData: makeSampleAudioData(),
        transcriptPreview: "今天的风很轻，路边的树影在晃，突然觉得这个早晨很值得被记住。",
        durationText: "00:02"
    )
    @State private var peopleData = PeopleCardData(
        people: [
            PersonCardItem(name: "Alice", nickname: "A", relationship: "Friend", mentionCount: 8),
            PersonCardItem(name: "Bob", relationship: "Colleague", mentionCount: 5),
        ]
    )
    @State private var newPersonName = ""
    @State private var newPersonNickname = ""
    @State private var newPersonRelationship = ""
    @State private var todayInHistoryData = TodayInHistoryCardData(
        monthDayLabel: "May 11",
        entries: []
    )

    private var photoCardSamples: [GridItem] {
        [
            GridItem(card: AnyView(PhotoCard(data: debugData)), columns: 4, units: 2),
            GridItem(card: AnyView(PhotoCard(data: debugData)), columns: 4, units: 4),
        ]
    }

    private var mapCardSamples: [GridItem] {
        [
            GridItem(card: AnyView(MapCard(data: mapData, onTap: { showMapSheet = true })), columns: 4, units: 2),
            GridItem(card: AnyView(MapCard(data: mapData, onTap: { showMapSheet = true })), columns: 4, units: 4),
        ]
    }

    private var linkCardSamples: [GridItem] {
        [
            GridItem(card: AnyView(LinkCard(data: linkData)), columns: 4, units: 2),
            GridItem(card: AnyView(LinkCard(data: linkData)), columns: 4, units: 4),
        ]
    }

    private var musicCardSamples: [GridItem] {
        [
            GridItem(card: AnyView(MusicCard(data: musicData.isEmpty ? nil : musicData, onTap: { showMusicSheet = true })), columns: 4, units: 1),
            GridItem(card: AnyView(MusicCard(data: musicData.isEmpty ? nil : musicData, onTap: { showMusicSheet = true })), columns: 4, units: 2),
            GridItem(card: AnyView(MusicCard(data: musicData.isEmpty ? nil : musicData, onTap: { showMusicSheet = true })), columns: 4, units: 4),
        ]
    }

    private var quoteCardSamples: [GridItem] {
        let d: QuoteCardData? = quoteData.isEmpty ? nil : quoteData
        return [
            GridItem(card: AnyView(QuoteCard(data: d)), columns: 4, units: 1),
            GridItem(card: AnyView(QuoteCard(data: d)), columns: 4, units: 2),
            GridItem(card: AnyView(QuoteCard(data: d)), columns: 4, units: 4),
        ]
    }

    private var weatherCardSamples: [GridItem] {
        let d: WeatherCardData? = weatherData.isEmpty ? nil : weatherData
        return [
            GridItem(card: AnyView(WeatherCard(data: d)), columns: 4, units: 1),
            GridItem(card: AnyView(WeatherCard(data: d)), columns: 4, units: 2),
            GridItem(card: AnyView(WeatherCard(data: d)), columns: 4, units: 4),
        ]
    }

    private var activityCardSamples: [GridItem] {
        let d: ActivityCardData? = activityData.isEmpty ? nil : activityData
        return [
            GridItem(card: AnyView(ActivityCard(data: d)), columns: 4, units: 1),
            GridItem(card: AnyView(ActivityCard(data: d)), columns: 4, units: 2),
            GridItem(card: AnyView(ActivityCard(data: d)), columns: 4, units: 4),
        ]
    }

    private var emotionCardSamples: [GridItem] {
        [
            GridItem(card: AnyView(EmotionCard(data: emotionData)), columns: 4, units: 1),
            GridItem(card: AnyView(EmotionCard(data: emotionData)), columns: 4, units: 2),
            GridItem(card: AnyView(EmotionCard(data: emotionData)), columns: 4, units: 4),
        ]
    }

    private var todoCardSamples: [GridItem] {
        let d: TodoCardData? = todoData.isEmpty ? nil : todoData
        return [
            GridItem(card: AnyView(TodoCard(data: d)), columns: 4, units: 1),
            GridItem(card: AnyView(TodoCard(data: d)), columns: 4, units: 2),
            GridItem(card: AnyView(TodoCard(data: d)), columns: 4, units: 4),
        ]
    }

    private var bookCardSamples: [GridItem] {
        let d: BookCardData? = bookData.isEmpty ? nil : bookData
        return [
            GridItem(card: AnyView(BookCard(data: d)), columns: 4, units: 1),
            GridItem(card: AnyView(BookCard(data: d)), columns: 4, units: 2),
            GridItem(card: AnyView(BookCard(data: d)), columns: 4, units: 4),
        ]
    }

    private var filmCardSamples: [GridItem] {
        let d: FilmCardData? = filmData.isEmpty ? nil : filmData
        return [
            GridItem(card: AnyView(FilmCard(data: d)), columns: 4, units: 1),
            GridItem(card: AnyView(FilmCard(data: d)), columns: 4, units: 2),
            GridItem(card: AnyView(FilmCard(data: d)), columns: 4, units: 4),
        ]
    }

    private var audioCardSamples: [GridItem] {
        let d: AudioCardData? = audioData.isEmpty ? nil : audioData
        return [
            GridItem(card: AnyView(AudioCard(data: d)), columns: 4, units: 1),
            GridItem(card: AnyView(AudioCard(data: d)), columns: 4, units: 2),
            GridItem(card: AnyView(AudioCard(data: d)), columns: 6, units: 4),
        ]
    }

    private var peopleCardSamples: [GridItem] {
        let d: PeopleCardData? = peopleData.isEmpty ? nil : peopleData
        return [
            GridItem(card: AnyView(PeopleCard(data: d)), columns: 2, units: 1),
            GridItem(card: AnyView(PeopleCard(data: d)), columns: 4, units: 2),
            GridItem(card: AnyView(PeopleCard(data: d)), columns: 6, units: 4),
        ]
    }

    private var todayInHistoryCardSamples: [GridItem] {
        let d: TodayInHistoryCardData? = todayInHistoryData.isEmpty ? nil : todayInHistoryData
        return [
            GridItem(card: AnyView(TodayInHistoryCard(data: d)), columns: 4, units: 1),
            GridItem(card: AnyView(TodayInHistoryCard(data: d)), columns: 4, units: 2),
            GridItem(card: AnyView(TodayInHistoryCard(data: d)), columns: 8, units: 4),
        ]
    }

    private var otherCardSamples: [GridItem] {
        [
            GridItem(card: AnyView(EmptyView()), columns: 4, units: 1),
            GridItem(card: AnyView(EmptyView()), columns: 4, units: 2),
            GridItem(card: AnyView(EmptyView()), columns: 4, units: 4),
        ]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
            Text("自适应预览")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)

            let items: [GridItem] = {
                switch cardType {
                case "PhotoCard": return photoCardSamples
                case "MapCard": return mapCardSamples
                case "LinkCard": return linkCardSamples
                case "MusicCard":    return musicCardSamples
                case "QuoteCard":   return quoteCardSamples
                case "WeatherCard": return weatherCardSamples
                case "ActivityCard":return activityCardSamples
                case "EmotionCard": return emotionCardSamples
                case "TodoCard":    return todoCardSamples
                case "AudioCard": return audioCardSamples
                case "PeopleCard": return peopleCardSamples
                case "TodayInHistoryCard": return todayInHistoryCardSamples
                case "BookCard":    return bookCardSamples
                case "FilmCard":    return filmCardSamples
                default: return otherCardSamples
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
            } else if cardType == "AudioCard" {
                audioDebugControlsSection
            } else if cardType == "PeopleCard" {
                peopleDebugControlsSection
            } else if cardType == "TodayInHistoryCard" {
                todayInHistoryDebugControlsSection
            } else if cardType == "BookCard" {
                bookDebugControlsSection
            } else if cardType == "FilmCard" {
                filmDebugControlsSection
            }
        }
        .navigationTitle(cardType)
        .onAppear {
            if todayInHistoryData.entries.isEmpty {
                todayInHistoryData = makeTodayInHistorySample(entryCount: 3)
            }
        }
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
                        let item = LinkItem(url: url, title: newLinkTitle, description: newLinkDescription)
                        // iconURL is computed automatically from domain
                        DispatchQueue.main.async {
                            withAnimation {
                                linkData.links.append(item)
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
            debugData.imagesData = []
            return
        }

        isLoadingImages = true
        Task {
            var loadedData: [Data] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    loadedData.append(data)
                }
            }
            await MainActor.run {
                debugData.imagesData = loadedData
                isLoadingImages = false
            }
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
                                if let artworkURL = nowPlaying.albumArtworkURL {
                                    AsyncImage(url: artworkURL) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray.opacity(0.2)
                                            .overlay(ProgressView())
                                    }
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
                // 获取天气按钮
                Button {
                    isFetchingWeather = true
                    Task {
                        if let location = weatherService.getCurrentLocation() {
                            do {
                                let data = try await weatherService.fetchWeather(for: location)
                                weatherData = data
                            } catch {
                                print("Weather fetch error: \(error)")
                            }
                        }
                        isFetchingWeather = false
                    }
                } label: {
                    Label(isFetchingWeather ? "正在获取..." : "获取当前天气", systemImage: "cloud.sun.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isFetchingWeather)

                Divider().padding(.horizontal, 4)

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

    @ViewBuilder
    private var audioDebugControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("调试控件").font(.headline).padding(.horizontal, 16)
            VStack(spacing: 12) {
                TextField("标题", text: $audioData.title)
                    .textFieldStyle(.roundedBorder)

                TextEditor(text: $audioData.transcriptPreview)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                TextField("时长文本", text: $audioData.durationText)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    Button("短录音") {
                        audioData.audioData = makeSampleAudioData(duration: 1.2, frequency: 520)
                        audioData.durationText = "00:01"
                    }
                    .buttonStyle(.bordered)

                    Button("长录音") {
                        audioData.audioData = makeSampleAudioData(duration: 4.8, frequency: 760)
                        audioData.durationText = "00:05"
                    }
                    .buttonStyle(.bordered)
                }

                Button("清空转写") {
                    audioData.transcriptPreview = ""
                }
                .buttonStyle(.bordered)

                Button("清除数据") {
                    audioData = AudioCardData()
                }
                .foregroundColor(.red)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private var peopleDebugControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("调试控件").font(.headline).padding(.horizontal, 16)
            VStack(spacing: 12) {
                TextField("姓名", text: $newPersonName).textFieldStyle(.roundedBorder)
                TextField("昵称", text: $newPersonNickname).textFieldStyle(.roundedBorder)
                TextField("关系", text: $newPersonRelationship).textFieldStyle(.roundedBorder)

                Button {
                    let item = PersonCardItem(
                        name: newPersonName,
                        nickname: newPersonNickname,
                        relationship: newPersonRelationship,
                        mentionCount: Int.random(in: 1...12)
                    )
                    peopleData.people.append(item)
                    newPersonName = ""
                    newPersonNickname = ""
                    newPersonRelationship = ""
                } label: {
                    Label("添加人物", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(newPersonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                HStack(spacing: 8) {
                    Button("单人预设") {
                        peopleData = PeopleCardData(
                            people: [PersonCardItem(name: "Mia", relationship: "Sister", mentionCount: 7)]
                        )
                    }
                    .buttonStyle(.bordered)

                    Button("多人预设") {
                        peopleData = PeopleCardData(
                            people: [
                                PersonCardItem(name: "Mia", relationship: "Sister", mentionCount: 7),
                                PersonCardItem(name: "David", relationship: "Colleague", mentionCount: 4),
                                PersonCardItem(name: "Nora", relationship: "Friend", mentionCount: 9),
                                PersonCardItem(name: "Leo", relationship: "Partner", mentionCount: 12),
                            ]
                        )
                    }
                    .buttonStyle(.bordered)
                }

                if !peopleData.people.isEmpty {
                    ForEach(peopleData.people) { person in
                        HStack {
                            Text(person.displayName)
                            Spacer()
                            Button {
                                peopleData.people.removeAll { $0.id == person.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }

                Button("清除数据") {
                    peopleData = PeopleCardData()
                }
                .foregroundColor(.red)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private var todayInHistoryDebugControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("调试控件").font(.headline).padding(.horizontal, 16)
            VStack(spacing: 12) {
                TextField("月日标签", text: $todayInHistoryData.monthDayLabel)
                    .textFieldStyle(.roundedBorder)

                Divider().padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 10) {
                    Text("系统卡配置").font(.caption).foregroundStyle(.secondary)
                    if let config = todayInHistorySystemConfig {
                        Toggle("启用首页往年今日卡", isOn: binding(for: config, keyPath: \.isEnabled))

                        HStack {
                            Text("宽度 \(config.widthColumns)")
                            Spacer()
                            Stepper("", value: binding(for: config, keyPath: \.widthColumns), in: 4...8, step: 2)
                                .labelsHidden()
                        }

                        HStack {
                            Text("高度 \(config.heightUnits)")
                            Spacer()
                            Picker("高度", selection: allowedHeightBinding(for: config)) {
                                Text("1").tag(1)
                                Text("2").tag(2)
                                Text("4").tag(4)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 132)
                        }

                        HStack {
                            Text("排序 \(Int(config.dashboardOrder))")
                            Spacer()
                            Stepper("", value: binding(for: config, keyPath: \.dashboardOrder), in: -20_000...20_000, step: 100)
                                .labelsHidden()
                        }
                    } else {
                        Button {
                            createTodayInHistorySystemConfig()
                        } label: {
                            Label("创建系统卡配置", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button("1 条") {
                        todayInHistoryData = makeTodayInHistorySample(entryCount: 1)
                    }
                    .buttonStyle(.bordered)
                    Button("3 条") {
                        todayInHistoryData = makeTodayInHistorySample(entryCount: 3)
                    }
                    .buttonStyle(.bordered)
                    Button("6 条") {
                        todayInHistoryData = makeTodayInHistorySample(entryCount: 6)
                    }
                    .buttonStyle(.bordered)
                }

                Button("无历史记录") {
                    todayInHistoryData = TodayInHistoryCardData(monthDayLabel: "May 11", entries: [])
                }
                .buttonStyle(.bordered)

                Button("清除数据") {
                    todayInHistoryData = TodayInHistoryCardData(monthDayLabel: "May 11", entries: [])
                }
                .foregroundColor(.red)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
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

    private func makeTodayInHistorySample(entryCount: Int) -> TodayInHistoryCardData {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let records = (0..<entryCount).map { index -> Record in
            let record = Record()
            let yearsAgo = index + 1
            record.createdAt = calendar.date(byAdding: .year, value: -yearsAgo, to: Date()) ?? Date()
            record.body = [
                "那天在公园里拍到了很好看的光影。",
                "第一次去了新的咖啡馆，记住了窗边的位置。",
                "和老朋友散步，聊了很久。",
                "完成了一个重要项目，晚上吃了庆祝晚餐。",
                "在路上听到喜欢的歌，突然很开心。",
                "整理旧照片时想起了很多事情。",
            ][index % 6]
            record.cardType = "text"
            return record
        }

        return TodayInHistoryCardData(
            monthDayLabel: "May 11",
            entries: records.map { TodayInHistoryEntry(record: $0, referenceYear: currentYear) }
        )
    }

    private var todayInHistorySystemConfig: DashboardSystemCardConfig? {
        systemConfigs.first(where: { $0.kind == DashboardSystemCardConfig.todayInHistoryKind })
    }

    private func createTodayInHistorySystemConfig() {
        let config = DashboardSystemCardConfig(
            kind: DashboardSystemCardConfig.todayInHistoryKind,
            isEnabled: true,
            widthColumns: 4,
            heightUnits: 2,
            dashboardOrder: -10_000
        )
        modelContext.insert(config)
    }

    private func binding<Value>(for object: DashboardSystemCardConfig, keyPath: ReferenceWritableKeyPath<DashboardSystemCardConfig, Value>) -> Binding<Value> {
        Binding(
            get: { object[keyPath: keyPath] },
            set: { object[keyPath: keyPath] = $0 }
        )
    }

    private func allowedHeightBinding(for object: DashboardSystemCardConfig) -> Binding<Int> {
        Binding(
            get: {
                if [1, 2, 4].contains(object.heightUnits) {
                    return object.heightUnits
                }
                return sizeLimits(for: DashboardSystemCardConfig.todayInHistoryKind)
                    .clamped(span: object.span)
                    .heightUnits
            },
            set: { object.heightUnits = $0 }
        )
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

    // MARK: - Book Debug

    @ViewBuilder
    private var bookDebugControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("调试控件").font(.headline).padding(.horizontal, 16)
            VStack(spacing: 12) {
                TextField("书名", text: $bookData.title).textFieldStyle(.roundedBorder)
                TextField("作者", text: $bookData.author).textFieldStyle(.roundedBorder)
                TextField("类型（如：文学/科幻）", text: Binding(
                    get: { bookData.genre ?? "" },
                    set: { bookData.genre = $0.isEmpty ? nil : $0 }
                )).textFieldStyle(.roundedBorder)
                if let progress = bookData.progress {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("进度 \(Int(progress * 100))%")
                            .font(.caption).foregroundStyle(.secondary)
                        Slider(value: Binding(get: { progress }, set: { bookData.progress = $0 }), in: 0...1)
                    }
                } else {
                    Button("设置阅读进度") { bookData.progress = 0 }
                        .font(.caption)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("评分").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                bookData.rating = star
                            } label: {
                                Image(systemName: (bookData.rating ?? 0) >= star ? "star.fill" : "star")
                                    .font(.system(size: 22))
                                    .foregroundStyle((bookData.rating ?? 0) >= star ? .orange : .secondary.opacity(0.3))
                            }
                        }
                    }
                }
                if !bookData.isEmpty {
                    Button("清除数据") { bookData = BookCardData() }.foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
    }

    // MARK: - Film Debug

    @ViewBuilder
    private var filmDebugControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("调试控件").font(.headline).padding(.horizontal, 16)
            VStack(spacing: 12) {
                TextField("电影名称", text: $filmData.title).textFieldStyle(.roundedBorder)
                TextField("年份", text: $filmData.year).textFieldStyle(.roundedBorder)
                TextField("导演", text: Binding(
                    get: { filmData.director ?? "" },
                    set: { filmData.director = $0.isEmpty ? nil : $0 }
                )).textFieldStyle(.roundedBorder)
                TextField("类型（如：动作/科幻）", text: Binding(
                    get: { filmData.genre ?? "" },
                    set: { filmData.genre = $0.isEmpty ? nil : $0 }
                )).textFieldStyle(.roundedBorder)
                VStack(alignment: .leading, spacing: 4) {
                    Text("评分").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                filmData.rating = Double(star)
                            } label: {
                                Image(systemName: (filmData.rating ?? 0) >= Double(star) ? "star.fill" : "star")
                                    .font(.system(size: 22))
                                    .foregroundStyle((filmData.rating ?? 0) >= Double(star) ? .orange : .secondary.opacity(0.3))
                            }
                        }
                        if let rating = filmData.rating {
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                }
                Toggle("已看过", isOn: $filmData.isWatched)
                    .padding(.horizontal, 4)
                if !filmData.isEmpty {
                    Button("清除数据") { filmData = FilmCardData() }.foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
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
