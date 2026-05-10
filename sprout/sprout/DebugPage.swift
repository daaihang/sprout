import SwiftUI
import PhotosUI
import MapKit

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
            }
        }
        .navigationTitle(cardType)
        .sheet(isPresented: $showMapSheet) {
            MapCardSheet(data: $mapData)
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
        case ("QuoteCard",    "4x1"): QuoteCard_4x1()
        case ("QuoteCard",    "4x2"): QuoteCard_4x2()
        case ("QuoteCard",    "4x4"): QuoteCard_4x4()
        case ("WeatherCard",  "4x1"): WeatherCard_4x1()
        case ("WeatherCard",  "4x2"): WeatherCard_4x2()
        case ("WeatherCard",  "4x4"): WeatherCard_4x4()
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
        default: EmptyView()
        }
    }
}

#Preview {
    NavigationStack {
        DebugPage()
    }
}
