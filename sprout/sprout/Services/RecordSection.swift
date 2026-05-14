// MARK: - RecordSection

/// Identifies a content section within a Record.
/// Used as the "entry angle" when navigating from a dashboard card to the detail view.
enum RecordSection: String, Hashable, CaseIterable {
    case text, emotion, weather, photo, music, link, map, todo, audio, people, todayInHistory
}
