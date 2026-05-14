// MARK: - RecordSection

/// Identifies a content section within a Record.
/// Used as the "entry angle" when navigating from a dashboard card to the detail view.
enum RecordSection: String, Hashable, CaseIterable {
    case text, emotion, weather, photo, music, link, activity, map, todo, audio, people, todayInHistory
}

// MARK: - Record helpers

extension Record {
    /// Extracts a value stored in tags with the format "key:value".
    func tagValue(for key: String) -> String {
        tags
            .first { $0.hasPrefix("\(key):") }
            .map { String($0.dropFirst(key.count + 1)) }
            ?? ""
    }
}
