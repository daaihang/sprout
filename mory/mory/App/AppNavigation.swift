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

enum SettingsRoute: String, CaseIterable, Hashable, Identifiable, Sendable {
    case account
    case permissions
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
        case .privacy: "lock.shield"
        case .dataControls: "externaldrive"
        case .capturePreferences: "slider.horizontal.3"
        case .appearanceLanguage: "textformat.size"
        case .diagnostics: "stethoscope"
        }
    }
}
