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
