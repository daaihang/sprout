import SwiftUI
import SwiftData
import PhotosUI

// MARK: - AddCardSheet

/// Sheet presented by the "+" button.
/// Creates standalone Records (independent of the text composer).
struct AddCardSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    var musicService: MusicService
    var selectedDate: Date

    // MARK: Internal navigation step

    private enum Step { case grid, emotion, weather, todo }
    @State private var step: Step = .grid

    // MARK: Sub-editor state

    @State private var emotionData  = EmotionCardData()
    @State private var weatherData  = WeatherCardData()
    @State private var todoData     = TodoCardData(title: "")

    // Sheets for types that re-use existing pickers
    @State private var musicData        = MusicCardData()
    @State private var locationData     = MapCardData()
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var capturedImages: [UIImage] = []

    @State private var showMusicSheet    = false
    @State private var showLocationSheet = false
    @State private var showPhotosPicker  = false

    // MARK: Body

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .grid:    gridView
                case .emotion: emotionEditorView
                case .weather: weatherEditorView
                case .todo:    todoEditorView
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .grid ? "取消" : "返回") {
                        if step == .grid { dismiss() } else { step = .grid }
                    }
                }
                if step != .grid {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") { confirmCurrentStep() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        // Music
        .sheet(isPresented: $showMusicSheet) {
            MusicCardSheet(data: $musicData, musicService: musicService)
                .onDisappear {
                    if !musicData.trackName.isEmpty { confirmStandalone(type: "music") }
                }
        }
        // Location
        .sheet(isPresented: $showLocationSheet) {
            MapCardSheet(data: $locationData)
                .onDisappear {
                    if locationData.coordinate != nil { confirmStandalone(type: "map") }
                }
        }
        // Photos
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $photoItems,
            maxSelectionCount: 9,
            matching: .images
        )
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img  = UIImage(data: data) {
                        images.append(img)
                    }
                }
                capturedImages = images
                if !images.isEmpty { confirmStandalone(type: "photo") }
            }
        }
    }

    // MARK: Grid

    private var gridView: some View {
        let types: [(label: String, icon: String, color: Color, action: () -> Void)] = [
            ("照片",  "photo.on.rectangle.angled", .blue,   { showPhotosPicker   = true }),
            ("心情",  "face.smiling",              .orange, { step = .emotion }),
            ("天气",  "cloud.sun.fill",             .yellow, { step = .weather }),
            ("地点",  "location.fill",              .red,    { showLocationSheet  = true }),
            ("待办",  "checklist",                  .green,  { step = .todo }),
            ("音乐",  "music.note",                 .purple, { showMusicSheet     = true }),
        ]
        return ScrollView {
            LazyVGrid(
                columns: [SwiftUI.GridItem(.flexible()), SwiftUI.GridItem(.flexible()), SwiftUI.GridItem(.flexible())],
                spacing: 20
            ) {
                ForEach(types, id: \.label) { item in
                    Button(action: item.action) {
                        VStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(item.color.opacity(0.12))
                                    .frame(width: 64, height: 64)
                                Image(systemName: item.icon)
                                    .font(.system(size: 26))
                                    .foregroundStyle(item.color)
                                    .symbolRenderingMode(.multicolor)
                            }
                            Text(item.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28)
        }
    }

    // MARK: Emotion editor

    private var emotionEditorView: some View {
        List {
            Section {
                LazyVGrid(
                    columns: Array(repeating: SwiftUI.GridItem(.flexible()), count: 3),
                    spacing: 12
                ) {
                    ForEach(MoodType.allCases, id: \.self) { mood in
                        Button { emotionData.mood = mood } label: {
                            VStack(spacing: 4) {
                                Text(mood.emoji).font(.system(size: 36))
                                Text(mood.label).font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                emotionData.mood == mood
                                    ? mood.color.opacity(0.18)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("心情")
            }

            Section {
                HStack(spacing: 16) {
                    Text("强度")
                        .font(.subheadline)
                    Spacer()
                    HStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { i in
                            Button { emotionData.intensity = i } label: {
                                Circle()
                                    .fill(i <= emotionData.intensity
                                          ? emotionData.mood.color
                                          : emotionData.mood.color.opacity(0.2))
                                    .frame(width: 26, height: 26)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                TextField("备注（可选）", text: $emotionData.note, axis: .vertical)
                    .lineLimit(2...5)
            } header: {
                Text("备注")
            }
        }
    }

    // MARK: Weather editor

    private var weatherEditorView: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(WeatherCondition.allCases, id: \.self) { cond in
                            Button { weatherData.condition = cond } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: cond.sfSymbol)
                                        .font(.system(size: 26))
                                        .foregroundStyle(cond.color)
                                        .symbolRenderingMode(.multicolor)
                                    Text(cond.label)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    weatherData.condition == cond
                                        ? cond.color.opacity(0.15)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("天气状况")
            }

            Section {
                Stepper(
                    "温度：\(Int(weatherData.temperature))°C",
                    value: $weatherData.temperature,
                    in: -40...60,
                    step: 1
                )
                Stepper(
                    "最高：\(Int(weatherData.high))°C",
                    value: $weatherData.high,
                    in: -40...60,
                    step: 1
                )
                Stepper(
                    "最低：\(Int(weatherData.low))°C",
                    value: $weatherData.low,
                    in: -40...60,
                    step: 1
                )
                Stepper(
                    "湿度：\(weatherData.humidity)%",
                    value: $weatherData.humidity,
                    in: 0...100,
                    step: 5
                )
            } header: {
                Text("气象数据")
            }

            Section {
                TextField("城市 / 地点名称", text: $weatherData.location)
            } header: {
                Text("地点")
            }
        }
    }

    // MARK: Todo editor

    private var todoEditorView: some View {
        List {
            Section {
                TextField("清单标题（可选）", text: $todoData.title)
            }

            Section {
                ForEach($todoData.items) { $item in
                    HStack(spacing: 12) {
                        Button { item.isDone.toggle() } label: {
                            Image(systemName: item.isDone
                                  ? "checkmark.square.fill" : "square")
                                .foregroundStyle(item.isDone ? .green : .secondary)
                                .font(.title3)
                        }
                        TextField("待办事项", text: $item.text)
                    }
                }
                .onDelete { todoData.items.remove(atOffsets: $0) }

                Button {
                    todoData.items.append(TodoItem(text: ""))
                } label: {
                    Label("添加项目", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            } header: {
                Text("待办项")
            }
        }
    }

    // MARK: Confirm helpers

    private var navTitle: String {
        switch step {
        case .grid:    return "新建卡片"
        case .emotion: return "记录心情"
        case .weather: return "记录天气"
        case .todo:    return "创建待办"
        }
    }

    private func confirmCurrentStep() {
        switch step {
        case .emotion: confirmStandalone(type: "emotion")
        case .weather: confirmStandalone(type: "weather")
        case .todo:    confirmStandalone(type: "todo")
        case .grid:    break
        }
    }

    /// Creates a standalone Record of the given type and inserts it into SwiftData.
    private func confirmStandalone(type cardType: String) {
        let record    = Record()
        let cal       = Calendar.current
        let today     = cal.startOfDay(for: Date())
        record.createdAt = cal.isDate(selectedDate, inSameDayAs: today)
            ? Date()
            : cal.date(byAdding: .day, value: 1, to: selectedDate)!.addingTimeInterval(-1)
        record.updatedAt = record.createdAt
        record.cardType  = cardType

        switch cardType {

        case "emotion":
            record.mood      = emotionData.mood.rawValue
            record.intensity = emotionData.intensity
            if !emotionData.note.isEmpty { record.body = emotionData.note }
            modelContext.insert(record)
            dismiss()

        case "weather":
            record.weather     = weatherData.condition.rawValue
            record.temperature = weatherData.temperature
            record.feelsLike   = weatherData.feelsLike
            record.humidity    = weatherData.humidity
            record.weatherHigh = weatherData.high
            record.weatherLow  = weatherData.low
            record.location    = weatherData.location.isEmpty ? nil : weatherData.location
            modelContext.insert(record)
            dismiss()

        case "map":
            record.latitude  = locationData.coordinate?.latitude
            record.longitude = locationData.coordinate?.longitude
            record.location  = locationData.locationName.isEmpty ? nil : locationData.locationName
            record.body      = locationData.descriptionText
            modelContext.insert(record)
            dismiss()

        case "music":
            let m = MediaCard()
            m.type    = "music"
            m.url     = musicData.appleMusicURL?.absoluteString
            m.title   = musicData.trackName
            m.caption = musicData.artistName
            if let img = musicData.albumArtwork {
                m.thumbnailData = img.jpegData(compressionQuality: 0.8)
            }
            modelContext.insert(m)
            modelContext.insert(record)
            record.mediaCards = [m]
            dismiss()

        case "photo":
            var cards: [MediaCard] = []
            for (i, img) in capturedImages.enumerated() {
                let m = MediaCard()
                m.type          = "photo"
                m.sortIndex     = i
                m.imageData     = img.jpegData(compressionQuality: 0.85)
                m.thumbnailData = img
                    .preparingThumbnail(of: CGSize(width: 300, height: 300))?
                    .jpegData(compressionQuality: 0.7)
                modelContext.insert(m)
                cards.append(m)
            }
            modelContext.insert(record)
            if !cards.isEmpty { record.mediaCards = cards }
            dismiss()

        case "todo":
            guard !todoData.isEmpty else { return }
            let m = MediaCard()
            m.type  = "todo"
            m.title = todoData.title
            if let json = try? JSONEncoder().encode(todoData.items) {
                m.caption = String(data: json, encoding: .utf8)
            }
            modelContext.insert(m)
            modelContext.insert(record)
            record.mediaCards = [m]
            dismiss()

        default:
            modelContext.insert(record)
            dismiss()
        }
    }
}
