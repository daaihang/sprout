import SwiftUI

enum DebugCardKind: String, CaseIterable, Identifiable, Hashable {
    case quote
    case weather
    case link
    case activity
    case music
    case emotion
    case todo
    case photo
    case map
    case audio
    case people
    case todayInHistory
    case book
    case film

    var id: String { rawValue }

    var cardTypeName: String {
        switch self {
        case .quote: return "QuoteCard"
        case .weather: return "WeatherCard"
        case .link: return "LinkCard"
        case .activity: return "ActivityCard"
        case .music: return "MusicCard"
        case .emotion: return "EmotionCard"
        case .todo: return "TodoCard"
        case .photo: return "PhotoCard"
        case .map: return "MapCard"
        case .audio: return "AudioCard"
        case .people: return "PeopleCard"
        case .todayInHistory: return "TodayInHistoryCard"
        case .book: return "BookCard"
        case .film: return "FilmCard"
        }
    }

    var gridCardType: String {
        switch self {
        case .quote: return "quote"
        case .weather: return "weather"
        case .link: return "link"
        case .activity: return "activity"
        case .music: return "music"
        case .emotion: return "emotion"
        case .todo: return "todo"
        case .photo: return "photo"
        case .map: return "map"
        case .audio: return "audio"
        case .people: return "people"
        case .todayInHistory: return "today_in_history"
        case .book: return "book"
        case .film: return "film"
        }
    }

    var symbolName: String {
        switch self {
        case .quote: return "quote.bubble"
        case .weather: return "cloud.sun"
        case .link: return "link"
        case .activity: return "figure.walk"
        case .music: return "music.note"
        case .emotion: return "face.smiling"
        case .todo: return "checklist"
        case .photo: return "photo.on.rectangle"
        case .map: return "map"
        case .audio: return "waveform"
        case .people: return "person.2"
        case .todayInHistory: return "clock.arrow.circlepath"
        case .book: return "book"
        case .film: return "film"
        }
    }

    var title: String { cardTypeName }
}
