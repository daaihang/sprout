import SwiftUI

struct HomeTopDrawerView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedDate: Date
    @Binding var selectedTag: HomeTopDrawerTag
    var isPresented: Bool = false
    var topContentInset: CGFloat = 0
    var outerCornerRadius: CGFloat = 34
    var onSelectTag: () -> Void = {}
    var onHeightChange: (CGFloat) -> Void = { _ in }

    private let drawerHorizontalInset: CGFloat = 16
    private let tagHeight: CGFloat = 38
    private let tagCalendarSpacing: CGFloat = 6
    private let bottomSpacing: CGFloat = 4
    private var tagCornerRadius: CGFloat { tagHeight / 2 }
    private var containerCornerRadius: CGFloat { tagCornerRadius * 2 }

    init(
        selectedDate: Binding<Date>,
        selectedTag: Binding<HomeTopDrawerTag>,
        isPresented: Bool = false,
        topContentInset: CGFloat = 0,
        outerCornerRadius: CGFloat = 34,
        onSelectTag: @escaping () -> Void = {},
        onHeightChange: @escaping (CGFloat) -> Void = { _ in }
    ) {
        _selectedDate = selectedDate
        _selectedTag = selectedTag
        self.isPresented = isPresented
        self.topContentInset = topContentInset
        self.outerCornerRadius = outerCornerRadius
        self.onSelectTag = onSelectTag
        self.onHeightChange = onHeightChange
    }

    var body: some View {
        ZStack(alignment: .top) {
            outerContainerMaterial

            drawerContent
                .clipShape(BottomRoundedRectangle(cornerRadius: containerCornerRadius))
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        onHeightChange(geometry.size.height)
                    }
                    .onChange(of: geometry.size.height) { _, newValue in
                        onHeightChange(newValue)
                    }
            }
        )
    }

    private var drawerContent: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: topContentInset)

            HStack(spacing: 0) {
                Color.clear
                    .frame(width: drawerHorizontalInset)

                tagStrip

                Color.clear
                    .frame(width: drawerHorizontalInset)
            }

            if selectedTag == .cards {
                Color.clear
                    .frame(height: tagCalendarSpacing)

                HomeDrawerCalendarStrip(
                    selectedDate: $selectedDate,
                    horizontalInset: drawerHorizontalInset,
                    isPresented: isPresented
                )

                Color.clear
                    .frame(height: bottomSpacing)
            } else {
                Color.clear
                    .frame(height: bottomSpacing)
            }
        }
    }

    @ViewBuilder
    private var outerContainerMaterial: some View {
        let cornerRadius = containerCornerRadius
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: BottomRoundedRectangle(cornerRadius: cornerRadius))
        } else {
            BottomRoundedRectangle(cornerRadius: cornerRadius)
                .fill(.thinMaterial)
                .overlay(
                    BottomRoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.white.opacity(colorScheme == .dark ? 0.12 : 0.20), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 6)
        }
    }

    private var tagStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(HomeTopDrawerTag.allCases) { tag in
                        Button {
                            selectedTag = tag
                            proxy.scrollTo(tag.id, anchor: .center)
                            onSelectTag()
                        } label: {
                            Label {
                                Text(localization.string(tag.localizationKey, default: tag.defaultTitle))
                                    .lineLimit(1)
                            } icon: {
                                Image(systemName: tag.systemImageName)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedTag == tag ? .white : .primary)
                            .padding(.horizontal, 14)
                            .frame(height: tagHeight)
                            .background(
                                Capsule()
                                    .fill(selectedTag == tag ? Color.primary.opacity(0.9) : Color.white.opacity(0.14))
                            )
                        }
                        .buttonStyle(.plain)
                        .id(tag.id)
                    }
                }
            }
            .onAppear {
                proxy.scrollTo(selectedTag.id, anchor: .center)
            }
            .onChange(of: selectedTag) { _, newTag in
                withTransaction(Transaction(animation: .smooth(duration: 0.24))) {
                    proxy.scrollTo(newTag.id, anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BottomRoundedRectangle: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, rect.width / 2, rect.height / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()

        return path
    }
}

enum HomeTopDrawerTag: String, CaseIterable, Identifiable {
    case cards
    case rawRecords
    case people
    case decisions
    case map
    case photos

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .cards:
            return "content.top_drawer.tag.cards"
        case .rawRecords:
            return "content.top_drawer.tag.raw_records"
        case .people:
            return "content.top_drawer.tag.people"
        case .decisions:
            return "content.top_drawer.tag.decisions"
        case .map:
            return "content.top_drawer.tag.map"
        case .photos:
            return "content.top_drawer.tag.photos"
        }
    }

    var defaultTitle: String {
        switch self {
        case .cards:
            return "卡片"
        case .rawRecords:
            return "原始记录"
        case .people:
            return "人物"
        case .decisions:
            return "决策"
        case .map:
            return "足迹地图"
        case .photos:
            return "图片墙"
        }
    }

    var systemImageName: String {
        switch self {
        case .cards:
            return "square.grid.2x2"
        case .rawRecords:
            return "list.bullet.rectangle"
        case .people:
            return "person.2"
        case .decisions:
            return "checkmark.circle"
        case .map:
            return "map"
        case .photos:
            return "photo.stack"
        }
    }

    init(persistedValue: String) {
        switch persistedValue {
        case Self.cards.rawValue, "flow":
            self = .cards
        case Self.rawRecords.rawValue:
            self = .rawRecords
        case Self.people.rawValue:
            self = .people
        case Self.decisions.rawValue:
            self = .decisions
        case Self.map.rawValue:
            self = .map
        case Self.photos.rawValue:
            self = .photos
        default:
            self = .cards
        }
    }
}
