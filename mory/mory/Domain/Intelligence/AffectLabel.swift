import Foundation

nonisolated enum AffectLabel: String, Codable, CaseIterable, Identifiable, Sendable {
    case excited
    case amazed
    case inspired
    case proud
    case curious
    case brave
    case confident
    case content
    case happy
    case hopeful
    case joyful
    case passionate
    case peaceful
    case satisfied
    case calm
    case grateful
    case relieved
    case warm
    case angry
    case annoyed
    case ashamed
    case disappointed
    case discouraged
    case disgusted
    case embarrassed
    case frustrated
    case guilty
    case hopeless
    case irritated
    case jealous
    case anxious
    case tense
    case overwhelmed
    case scared
    case surprised
    case worried
    case drained
    case indifferent
    case tired
    case sad
    case lonely
    case numb
    case amused
    case mockFrustrated
    case stressed
    case playful
    case uncertain

    var id: String { rawValue }
}

nonisolated enum ToneHint: String, Codable, CaseIterable, Identifiable, Sendable {
    case joking
    case playful
    case sarcastic
    case venting
    case serious
    case tender
    case exhausted
    case uncertain

    var id: String { rawValue }
}
