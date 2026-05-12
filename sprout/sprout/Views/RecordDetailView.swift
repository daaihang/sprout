import SwiftUI
import UIKit
import MapKit

// MARK: - RecordDetailView

/// Full-screen detail view for a single Record.
/// The `focusedSection` parameter determines which content block appears first —
/// so tapping a MusicCard opens this view with music at the top, while tapping
/// a QuoteCard shows the text first. All content still follows below.
struct RecordDetailView: View {
    @Environment(AppLocalization.self) private var localization
    let record: Record
    var focusedSection: RecordSection = .text

    // MARK: Section ordering

    private var orderedSections: [RecordSection] {
        var all = availableSections
        if let idx = all.firstIndex(of: focusedSection) {
            all.remove(at: idx)
            all.insert(focusedSection, at: 0)
        }
        return all
    }

    private var availableSections: [RecordSection] {
        var sections: [RecordSection] = []
        let media = record.mediaCards ?? []
        if media.contains(where: { $0.type == "photo" })  { sections.append(.photo) }
        if media.contains(where: { $0.type == "music" })  { sections.append(.music) }
        if media.contains(where: { $0.type == "audio" })  { sections.append(.audio) }
        if media.contains(where: { $0.type == "link" })   { sections.append(.link) }
        if record.latitude != nil                         { sections.append(.map) }
        if record.activity?.value != nil                  { sections.append(.activity) }
        if record.mood != nil                             { sections.append(.emotion) }
        if record.weather != nil                          { sections.append(.weather) }
        if media.contains(where: { $0.type == "todo" })  { sections.append(.todo) }
        if !(record.mentionedPeople ?? []).isEmpty       { sections.append(.people) }
        if !record.body.isEmpty                           { sections.append(.text) }
        return sections
    }

    // MARK: Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(orderedSections, id: \.self) { section in
                    sectionView(for: section)
                }
                metadataFooter.padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .padding(.bottom, 40)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var navigationTitle: String {
        if !record.body.isEmpty { return String(record.body.prefix(24)) }
        if let loc = record.location, !loc.isEmpty { return loc }
        return t("detail.navigation.record", "Entry")
    }

    // MARK: Section dispatcher

    @ViewBuilder
    private func sectionView(for section: RecordSection) -> some View {
        switch section {
        case .text:     textSection
        case .emotion:  emotionSection
        case .weather:  weatherSection
        case .photo:    photoSection
        case .music:    musicSection
        case .audio:    audioSection
        case .link:     linkSection
        case .activity: activitySection
        case .map:      mapSection
        case .todo:     todoSection
        case .people:   peopleSection
        case .todayInHistory:
            EmptyView()
        }
    }

    // MARK: - Text

    private var textSection: some View {
        let author = record.tagValue(for: "author")
        let source = record.tagValue(for: "source")
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(icon: "text.alignleft", title: t("detail.section.body", "Body"))
            Text(record.body)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !author.isEmpty || !source.isEmpty {
                HStack(spacing: 4) {
                    if !author.isEmpty { Text("— \(author)") }
                    if !source.isEmpty { Text("·  \(source)") }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .detailCard()
    }

    // MARK: - Emotion

    @ViewBuilder
    private var emotionSection: some View {
        if let moodStr = record.mood, let mood = MoodType(rawValue: moodStr) {
            let intensity = record.intensity ?? 3
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "face.smiling", title: t("detail.section.emotion", "Emotion"))
                HStack(spacing: 14) {
                    Text(mood.emoji).font(.system(size: 48))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(mood.label).font(.title3.weight(.semibold))
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { i in
                                Circle()
                                    .fill(i <= intensity ? mood.color : mood.color.opacity(0.2))
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                    Spacer()
                }
            }
            .detailCard()
        }
    }

    // MARK: - Weather

    @ViewBuilder
    private var weatherSection: some View {
        if let weatherStr = record.weather, let condition = WeatherCondition(rawValue: weatherStr) {
            let temp = record.temperature ?? 20
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "cloud.sun.fill", title: t("detail.section.weather", "Weather"))
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(temp))°")
                            .font(.system(size: 42, weight: .semibold, design: .rounded))
                        Text(condition.label).font(.subheadline).foregroundStyle(.secondary)
                        if let loc = record.location, !loc.isEmpty {
                            Label(loc, systemImage: "location.fill")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if let observedAt = record.weatherObservedAt {
                            Label(observedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: condition.sfSymbol)
                        .font(.system(size: 48))
                        .foregroundStyle(condition.color)
                        .symbolRenderingMode(.multicolor)
                }
            }
            .detailCard()
        }
    }

    // MARK: - Photos

    @ViewBuilder
    private var photoSection: some View {
        let photos = (record.mediaCards ?? []).filter { $0.type == "photo" }
        if !photos.isEmpty {
            let images: [UIImage] = photos.compactMap { m in
                m.imageData.flatMap { UIImage(data: $0) }
            }
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "photo.on.rectangle.angled", title: t("detail.section.photos", "Photos"))
                if images.isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: "photo").font(.largeTitle)
                                .foregroundStyle(.secondary.opacity(0.4))
                        )
                } else if images.count == 1 {
                    Image(uiImage: images[0])
                        .resizable().aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity).frame(height: 260).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    TabView {
                        ForEach(images.indices, id: \.self) { idx in
                            Image(uiImage: images[idx])
                                .resizable().aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity).clipped()
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                let photoLoc = photos.first?.locationName ?? record.location
                if let loc = photoLoc, !loc.isEmpty {
                    Label(loc, systemImage: "location.fill")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .detailCard()
        }
    }

    // MARK: - Music

    @ViewBuilder
    private var musicSection: some View {
        if let m = (record.mediaCards ?? []).first(where: { $0.type == "music" }) {
            let artwork: UIImage? = m.thumbnailData.flatMap { UIImage(data: $0) }
            let artworkURL = m.artworkURLString.flatMap(URL.init(string:))
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "music.note", title: t("detail.section.music", "Music"))
                HStack(spacing: 14) {
                    Group {
                        if let img = artwork {
                            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                        } else if let artworkURL {
                            CachedRemoteImage(url: artworkURL, contentMode: .fill) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.secondary.opacity(0.15))
                                    .overlay(ProgressView())
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.15))
                                .overlay(
                                    Image(systemName: "music.note").font(.title2)
                                        .foregroundStyle(.secondary.opacity(0.5))
                                )
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(m.title ?? t("detail.music.unknown_track", "Unknown Track")).font(.headline).lineLimit(2)
                        Text(m.caption ?? "").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        if let albumName = m.albumName, !albumName.isEmpty {
                            Text(albumName)
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.8))
                                .lineLimit(1)
                        }
                        if let urlStr = m.url, let url = URL(string: urlStr) {
                            Link(t("detail.music.open_apple_music", "Open in Apple Music"), destination: url).font(.caption)
                        }
                    }
                    Spacer()
                }
            }
            .detailCard()
        }
    }

    // MARK: - Links

    @ViewBuilder
    private var audioSection: some View {
        if let audio = (record.mediaCards ?? []).first(where: { $0.type == "audio" }) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "waveform", title: t("detail.section.audio", "Voice"))
                AudioCard(
                    data: AudioCardData(
                        title: audio.title ?? "",
                        audioData: audio.audioData,
                        transcriptPreview: audio.caption ?? "",
                        durationText: audioDurationString(from: audio.audioData),
                        capturedAt: audio.capturedAt ?? record.createdAt
                    )
                )
                .frame(height: 180)
            }
            .detailCard()
        }
    }

    @ViewBuilder
    private var linkSection: some View {
        let links = (record.mediaCards ?? []).filter { $0.type == "link" }
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "link", title: t("detail.section.links", "Links"))
                ForEach(links) { m in
                    if let urlStr = m.url, let url = URL(string: urlStr) {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.1))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "safari.fill").font(.system(size: 18))
                                        .foregroundStyle(Color.accentColor)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.title ?? urlStr)
                                    .font(.subheadline.weight(.medium)).lineLimit(1)
                                Text(url.host ?? urlStr)
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Link(destination: url) {
                                Image(systemName: "arrow.up.right.square").foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .detailCard()
        }
    }

    // MARK: - Activity

    @ViewBuilder
    private var peopleSection: some View {
        let people = record.mentionedPeople ?? []
        if !people.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "person.2.fill", title: t("detail.section.people", "People"))
                ForEach(people, id: \.id) { person in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.14))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(person.initials)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.displayName)
                                .font(.subheadline.weight(.semibold))
                            if !person.secondaryLabel.isEmpty {
                                Text(person.secondaryLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if person.mentionCount > 0 {
                            Text("\(person.mentionCount)x")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .detailCard()
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        if let act = record.activity, let value = act.value {
            let actType = ActivityType(rawValue: act.type) ?? .steps
            let formatted = value.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", value) : String(format: "%.1f", value)
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: actType.sfSymbol, title: actType.label)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formatted)
                        .font(.system(size: 52, weight: .semibold, design: .rounded))
                        .foregroundStyle(actType.color)
                    Text(act.unit ?? actType.defaultUnit)
                        .font(.title3).foregroundStyle(.secondary).offset(y: -4)
                    Spacer()
                }
                if let goal = act.goal, goal > 0 {
                    let progress = min(value / goal, 1.0)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(actType.color.opacity(0.15)).frame(height: 8)
                            RoundedRectangle(cornerRadius: 4).fill(actType.color)
                                .frame(width: geo.size.width * progress, height: 8)
                        }
                    }
                    .frame(height: 8)
                    Text(t("detail.activity.goal_progress", "Goal %d · %d%%", Int(goal), Int(progress * 100)))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let dur = act.durationMinutes, dur > 0 {
                    Label(t("detail.activity.duration_minutes", "%d min", dur), systemImage: "clock")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .detailCard()
        }
    }

    // MARK: - Map

    @ViewBuilder
    private var mapSection: some View {
        if let lat = record.latitude, let lng = record.longitude {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "map.fill", title: t("detail.section.location", "Location"))
                MapSnapshotView(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
                )
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                if let loc = record.location, !loc.isEmpty {
                    Label(loc, systemImage: "location.fill")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .detailCard()
        }
    }

    // MARK: - Todo

    @ViewBuilder
    private var todoSection: some View {
        if let payload = decodedTodoItems() {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(icon: "checklist", title: payload.title)
                ForEach(payload.items) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                            .foregroundStyle(item.isDone ? .green : .secondary)
                            .font(.system(size: 16))
                        Text(item.text)
                            .font(.body)
                            .foregroundStyle(item.isDone ? .secondary : .primary)
                            .strikethrough(item.isDone)
                    }
                }
                let doneCount = payload.items.filter(\.isDone).count
                Text(t("detail.todo.completed", "%d/%d completed", doneCount, payload.items.count))
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
            }
            .detailCard()
        }
    }

    /// Decodes todo items from MediaCard JSON. Extracted to avoid var mutation inside ViewBuilder.
    private func decodedTodoItems() -> (title: String, items: [TodoItem])? {
        guard let m = (record.mediaCards ?? []).first(where: { $0.type == "todo" }),
              let json = m.caption,
              let raw = json.data(using: .utf8),
              let items = try? JSONDecoder().decode([TodoItem].self, from: raw),
              !items.isEmpty
        else { return nil }
        return (m.title ?? t("detail.todo.default_title", "To-Do"), items)
    }

    // MARK: - Metadata footer

    private var metadataFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack(spacing: 16) {
                Label(formattedDate(record.createdAt), systemImage: "clock")
                if record.latitude == nil, let loc = record.location, !loc.isEmpty {
                    Label(loc, systemImage: "location")
                }
            }
            .font(.caption).foregroundStyle(.secondary)

            let displayTags = record.tags.filter {
                !$0.hasPrefix("author:") && !$0.hasPrefix("source:")
            }
            if !displayTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(displayTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.1), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        localization.templateDateString(from: date, template: "MMM d HH:mm")
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}

// MARK: - Section label

private struct SectionLabel: View {
    let icon: String
    let title: String
    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Map snapshot

private struct MapSnapshotView: View {
    let coordinate: CLLocationCoordinate2D
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .overlay(ProgressView())
                    .task { await loadSnapshot() }
            }
        }
    }

    @MainActor
    private func loadSnapshot() async {
        let opts = MKMapSnapshotter.Options()
        opts.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 800, longitudinalMeters: 800
        )
        opts.size = CGSize(width: 360, height: 200)
        opts.scale = UIScreen.main.scale
        if let snap = try? await MKMapSnapshotter(options: opts).start() {
            image = snap.image
        }
    }
}

// MARK: - Card modifier

private extension View {
    func detailCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.85),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RecordDetailView(record: {
            let r = Record()
            r.body = "今天读到了一句话，让人感触很深：生活不是等待暴风雨过去，而是学会在雨中起舞。"
            r.mood = MoodType.calm.rawValue
            r.intensity = 4
            r.weather = WeatherCondition.partlyCloudy.rawValue
            r.temperature = 22
            r.location = "北京"
            r.tags = ["author:佚名", "reading"]
            return r
        }(), focusedSection: .text)
    }
}
