import Foundation
import SwiftData

@Model
final class Person {
    var id: UUID = UUID()
    var name: String = ""
    var nickname: String? = nil
    var relationship: String? = nil
    var birthday: Date? = nil
    var note: String? = nil
    var contactIdentifier: String? = nil
    var lastMentionedAt: Date? = nil
    var mentionCount: Int = 0
    var reminderIntervalDays: Int? = nil
    @Attribute(.externalStorage) var avatarImageData: Data? = nil

    @Relationship(inverse: \Record.mentionedPeople) var records: [Record]? = nil

    init() {}
}

extension Person {
    var displayName: String {
        let trimmedNickname = (nickname ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedNickname.isEmpty ? name : trimmedNickname
    }

    var secondaryLabel: String {
        let trimmedRelationship = (relationship ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRelationship.isEmpty { return trimmedRelationship }
        let trimmedNickname = (nickname ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNickname.isEmpty && trimmedNickname != name { return name }
        return ""
    }

    var initials: String {
        let components = name
            .split(whereSeparator: { $0 == " " || $0 == "-" })
            .prefix(2)
            .map { String($0.prefix(1)) }
        return components.isEmpty ? String(name.prefix(1)).uppercased() : components.joined().uppercased()
    }
}
