import SwiftUI

// Minimal drawer shell retained as a geometry placeholder while top tabs own the active UI.
struct HomeTopDrawerView: View {
    @Binding var selectedDate: Date
    @Binding var selectedTag: HomeTopDrawerTag
    var isPresented: Bool = false
    var topContentInset: CGFloat = 0
    var outerCornerRadius: CGFloat = 34
    var onSelectTag: () -> Void = {}
    var onHeightChange: (CGFloat) -> Void = { _ in }

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
        Color.clear
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
    case people
    case rawRecords
    case arcs
    case reflections
    case search
    case decisions
    case map
    case photos

    static var allCases: [HomeTopDrawerTag] {
        [.cards, .people, .rawRecords, .arcs, .reflections, .search]
    }

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .cards:
            return "content.top_drawer.tag.cards"
        case .rawRecords:
            return "content.top_drawer.tag.raw_records"
        case .search:
            return "content.top_drawer.tag.search"
        case .arcs:
            return "content.top_drawer.tag.arcs"
        case .reflections:
            return "content.top_drawer.tag.reflections"
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
        case .search:
            return "搜索"
        case .arcs:
            return "阶段"
        case .reflections:
            return "反思"
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
        case .search:
            return "magnifyingglass"
        case .arcs:
            return "timeline.selection"
        case .reflections:
            return "sparkles"
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
        case Self.search.rawValue, Self.decisions.rawValue, Self.map.rawValue, Self.photos.rawValue:
            self = .search
        case Self.arcs.rawValue:
            self = .arcs
        case Self.people.rawValue:
            self = .people
        default:
            self = .cards
        }
    }
}
