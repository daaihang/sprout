import Combine
import Foundation

enum MoryAppTab: String, CaseIterable, Hashable, Identifiable, Sendable {
    case today
    case memories
    case insights
    case search

    static let publicTabs: [MoryAppTab] = [.today, .memories, .insights, .search]

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .today: "tab.today"
        case .memories: "tab.memories"
        case .insights: "tab.insights"
        case .search: "search.nav.title"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "house.fill"
        case .memories: "archivebox.fill"
        case .insights: "chart.line.uptrend.xyaxis"
        case .search: "magnifyingglass"
        }
    }
}

enum MoryDeepLinkRoute: Hashable, Sendable {
    case homeRoot
    case home(HomeRoute)
    case memories(MemoriesRoute)
    case insights(InsightsRoute)
    case search

    static func parse(_ string: String) -> MoryDeepLinkRoute? {
        guard let url = URL(string: string),
              url.scheme?.lowercased() == "mory" else {
            return nil
        }

        let pathSegments = url.path
            .split(separator: "/")
            .map(String.init)
        guard let host = url.host?.lowercased() else {
            return nil
        }

        switch host {
        case "home":
            if pathSegments.isEmpty {
                return .homeRoot
            }
            guard pathSegments.count == 2,
                  pathSegments[0] == "question",
                  let id = UUID(uuidString: pathSegments[1]) else {
                return nil
            }
            return .home(.question(id))

        case "memories":
            guard pathSegments.count == 2 else { return nil }
            switch pathSegments[0] {
            case "record":
                guard let id = UUID(uuidString: pathSegments[1]) else { return nil }
                return .memories(.memory(id))
            default:
                return nil
            }

        case "insights":
            guard pathSegments.count == 2,
                  let id = UUID(uuidString: pathSegments[1]) else {
                return nil
            }
            switch pathSegments[0] {
            case "chapter":
                return .insights(.arc(id))
            case "reflection":
                return .insights(.reflection(id))
            case "entity", "place", "theme", "decision":
                return .insights(.entity(id))
            default:
                return nil
            }

        case "search":
            return .search

        default:
            return nil
        }
    }
}

@MainActor
final class NavigationRouteCoordinator: ObservableObject {
    @Published var selectedTab: MoryAppTab = .today
    @Published var homeRoute: HomeRoute?
    @Published var memoriesRoute: MemoriesRoute?
    @Published var insightsRoute: InsightsRoute?

    func apply(_ route: NotificationInteractionRoute) {
        if let deepLink = route.deepLink {
            apply(deepLink)
            return
        }

        switch route.destination {
        case .home:
            selectedTab = .today
        case .memories:
            selectedTab = .memories
        case .insights:
            selectedTab = .insights
        case .search:
            selectedTab = .search
        }
    }

    func apply(_ deepLink: MoryDeepLinkRoute) {
        switch deepLink {
        case .homeRoot:
            selectedTab = .today
        case let .home(route):
            selectedTab = .today
            homeRoute = nil
            homeRoute = route
        case let .memories(route):
            selectedTab = .memories
            memoriesRoute = nil
            memoriesRoute = route
        case let .insights(route):
            selectedTab = .insights
            insightsRoute = nil
            insightsRoute = route
        case .search:
            selectedTab = .search
        }
    }
}

enum MemoriesRoute: Hashable, Identifiable, Sendable {
    case memory(UUID)

    var id: String {
        switch self {
        case let .memory(id):
            return "memory-\(id.uuidString)"
        }
    }
}

enum InsightsRoute: Hashable, Identifiable, Sendable {
    case arc(UUID)
    case reflection(UUID)
    case entity(UUID)

    var id: String {
        switch self {
        case let .arc(id):
            return "arc-\(id.uuidString)"
        case let .reflection(id):
            return "reflection-\(id.uuidString)"
        case let .entity(id):
            return "entity-\(id.uuidString)"
        }
    }
}

enum SettingsRoute: String, CaseIterable, Hashable, Identifiable, Sendable {
    case account
    case permissions
    case notifications
    case memoryIntelligence
    case places
    case privacy
    case dataControls
    case capturePreferences
    case appearanceLanguage
    case diagnostics

    var id: String { rawValue }

    static func visibleRoutes(allowsDebugTools: Bool) -> [SettingsRoute] {
        allCases.filter { route in
            route != .diagnostics || allowsDebugTools
        }
    }

    var titleKey: String {
        switch self {
        case .account: "settings.account.title"
        case .permissions: "settings.permissions.title"
        case .notifications: "settings.notifications.title"
        case .memoryIntelligence: "Memory Intelligence"
        case .places: "Places"
        case .privacy: "settings.privacy.title"
        case .dataControls: "settings.data.title"
        case .capturePreferences: "settings.capture.title"
        case .appearanceLanguage: "settings.appearance.title"
        case .diagnostics: "settings.diagnostics.title"
        }
    }

    var subtitleKey: String {
        switch self {
        case .account: "settings.account.subtitle"
        case .permissions: "settings.permissions.subtitle"
        case .notifications: "settings.notifications.subtitle"
        case .memoryIntelligence: "Review graph deltas, affect history, journaling status, and external drafts"
        case .places: "Rename, merge, and split saved places"
        case .privacy: "settings.privacy.subtitle"
        case .dataControls: "settings.data.subtitle"
        case .capturePreferences: "settings.capture.subtitle"
        case .appearanceLanguage: "settings.appearance.subtitle"
        case .diagnostics: "settings.diagnostics.subtitle"
        }
    }

    var systemImage: String {
        switch self {
        case .account: "person.crop.circle"
        case .permissions: "hand.raised"
        case .notifications: "bell.badge"
        case .memoryIntelligence: "brain.head.profile"
        case .places: "mappin.and.ellipse"
        case .privacy: "lock.shield"
        case .dataControls: "externaldrive"
        case .capturePreferences: "slider.horizontal.3"
        case .appearanceLanguage: "textformat.size"
        case .diagnostics: "stethoscope"
        }
    }
}
