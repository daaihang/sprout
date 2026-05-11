import Foundation
import Observation

private enum LocalizationLookup {
    static func resolveLanguageIdentifier() -> String {
        Bundle.main.preferredLocalizations.first
            ?? Locale.preferredLanguages.first
            ?? AppLocalization.SupportedLanguage.english.rawValue
    }

    static func localizedBundle(for identifier: String) -> Bundle {
        let language = AppLocalization.SupportedLanguage(resolvedIdentifier: identifier)
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    static func locale(for identifier: String) -> Locale {
        AppLocalization.SupportedLanguage(resolvedIdentifier: identifier).locale
    }

    static func resolvedTableName(for key: String, explicitTable: String?) -> String? {
        if let explicitTable, !explicitTable.isEmpty {
            return explicitTable
        }

        if key.hasPrefix("common.") {
            return "Common"
        }
        if key.hasPrefix("account.") {
            return "Account"
        }
        if key.hasPrefix("subscription.") || key.hasPrefix("paywall.") {
            return "Subscription"
        }
        if key.hasPrefix("content.") {
            return "Content"
        }
        if key.hasPrefix("toolbar.") {
            return "Toolbar"
        }
        if key.hasPrefix("add_card.") {
            return "AddCard"
        }
        if key.hasPrefix("detail.") {
            return "Detail"
        }
        if key.hasPrefix("card.") || key.hasPrefix("mood.") || key.hasPrefix("weather.") || key.hasPrefix("activity.") {
            return "Cards"
        }

        return nil
    }

    static func string(_ key: String, default defaultValue: String, table: String? = nil) -> String {
        let identifier = resolveLanguageIdentifier()
        let bundle = localizedBundle(for: identifier)
        return bundle.localizedString(
            forKey: key,
            value: defaultValue,
            table: resolvedTableName(for: key, explicitTable: table)
        )
    }

    static func string(_ key: String, default defaultValue: String, table: String? = nil, arguments: [CVarArg]) -> String {
        let identifier = resolveLanguageIdentifier()
        let format = string(key, default: defaultValue, table: table)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale(for: identifier), arguments: arguments)
    }
}

@Observable
@MainActor
final class AppLocalization {
    static let shared = AppLocalization()

    enum SupportedLanguage: String, CaseIterable, Equatable {
        case simplifiedChinese = "zh-Hans"
        case traditionalChinese = "zh-Hant"
        case english = "en"
        case japanese = "ja"

        init(resolvedIdentifier: String) {
            let normalized = resolvedIdentifier.lowercased()

            if normalized.hasPrefix("zh-hant") || normalized.hasPrefix("zh-tw") || normalized.hasPrefix("zh-hk") || normalized.hasPrefix("zh-mo") {
                self = .traditionalChinese
            } else if normalized.hasPrefix("zh-hans") || normalized.hasPrefix("zh-cn") || normalized.hasPrefix("zh-sg") || normalized.hasPrefix("zh") {
                self = .simplifiedChinese
            } else if normalized.hasPrefix("ja") {
                self = .japanese
            } else {
                self = .english
            }
        }

        var locale: Locale {
            Locale(identifier: rawValue)
        }

        var nativeDisplayName: String {
            switch self {
            case .simplifiedChinese:
                return "简体中文"
            case .traditionalChinese:
                return "繁體中文"
            case .english:
                return "English"
            case .japanese:
                return "日本語"
            }
        }
    }

    var currentLanguage: SupportedLanguage

    private init() {
        currentLanguage = Self.resolveCurrentLanguage()
    }

    var locale: Locale {
        currentLanguage.locale
    }

    func refreshIfNeeded() {
        let resolvedLanguage = Self.resolveCurrentLanguage()
        guard resolvedLanguage != currentLanguage else { return }
        currentLanguage = resolvedLanguage
    }

    func string(_ key: String, default defaultValue: String, table: String? = nil) -> String {
        let bundle = LocalizationLookup.localizedBundle(for: currentLanguage.rawValue)
        return bundle.localizedString(
            forKey: key,
            value: defaultValue,
            table: LocalizationLookup.resolvedTableName(for: key, explicitTable: table)
        )
    }

    func string(_ key: String, default defaultValue: String, table: String? = nil, arguments: [CVarArg]) -> String {
        let format = string(key, default: defaultValue, table: table)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: arguments)
    }

    func longDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func shortTimeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    func templateDateString(from date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    static func localizedString(_ key: String, default defaultValue: String, table: String? = nil) -> String {
        LocalizationLookup.string(key, default: defaultValue, table: table)
    }

    static func localizedString(_ key: String, default defaultValue: String, table: String? = nil, arguments: [CVarArg]) -> String {
        LocalizationLookup.string(key, default: defaultValue, table: table, arguments: arguments)
    }

    private static func resolveCurrentLanguage() -> SupportedLanguage {
        let resolvedIdentifier = LocalizationLookup.resolveLanguageIdentifier()
        return SupportedLanguage(resolvedIdentifier: resolvedIdentifier)
    }
}

func localizedString(_ key: String, default defaultValue: String, table: String? = nil) -> String {
    LocalizationLookup.string(key, default: defaultValue, table: table)
}

func localizedString(_ key: String, default defaultValue: String, table: String? = nil, arguments: [CVarArg]) -> String {
    LocalizationLookup.string(key, default: defaultValue, table: table, arguments: arguments)
}
