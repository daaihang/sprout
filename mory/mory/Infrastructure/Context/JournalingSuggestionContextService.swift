import Foundation

enum JournalingSuggestionAvailabilityReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case available
    case unsupportedOS
    case missingEntitlement
    case disabledByUser
    case frameworkNotLinked

    var id: String { rawValue }
}

struct JournalingSuggestionAvailability: Codable, Hashable, Sendable {
    var isAvailable: Bool
    var reason: JournalingSuggestionAvailabilityReason
    var detail: String

    static var available: JournalingSuggestionAvailability {
        JournalingSuggestionAvailability(
            isAvailable: true,
            reason: .available,
            detail: "Journaling Suggestions capability is available."
        )
    }
}

protocol JournalingSuggestionCapabilityProviding: Sendable {
    var supportsJournalingSuggestions: Bool { get }
    var hasJournalingSuggestionEntitlement: Bool { get }
    var userEnabledJournalingSuggestions: Bool { get }
}

struct DefaultJournalingSuggestionCapabilityProvider: JournalingSuggestionCapabilityProviding {
    var supportsJournalingSuggestions: Bool {
        if #available(iOS 17.2, *) {
            true
        } else {
            false
        }
    }

    var hasJournalingSuggestionEntitlement: Bool {
        false
    }

    var userEnabledJournalingSuggestions: Bool {
        true
    }
}

struct JournalingSuggestionDraft: Codable, Hashable, Sendable {
    var title: String?
    var body: String?
    var reflectionPrompt: String?
    var locationTitle: String?
    var latitude: Double?
    var longitude: Double?
    var songTitle: String?
    var artistName: String?
    var workoutSummary: String?
    var stateOfMindLabel: String?
    var stateOfMindValence: Double?
    var stateOfMindArousal: Double?
    var stateOfMindDominance: Double?
    var createdAt: Date

    init(
        title: String? = nil,
        body: String? = nil,
        reflectionPrompt: String? = nil,
        locationTitle: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        songTitle: String? = nil,
        artistName: String? = nil,
        workoutSummary: String? = nil,
        stateOfMindLabel: String? = nil,
        stateOfMindValence: Double? = nil,
        stateOfMindArousal: Double? = nil,
        stateOfMindDominance: Double? = nil,
        createdAt: Date = .now
    ) {
        self.title = title
        self.body = body
        self.reflectionPrompt = reflectionPrompt
        self.locationTitle = locationTitle
        self.latitude = latitude
        self.longitude = longitude
        self.songTitle = songTitle
        self.artistName = artistName
        self.workoutSummary = workoutSummary
        self.stateOfMindLabel = stateOfMindLabel
        self.stateOfMindValence = stateOfMindValence
        self.stateOfMindArousal = stateOfMindArousal
        self.stateOfMindDominance = stateOfMindDominance
        self.createdAt = createdAt
    }
}

enum ExternalCaptureSourceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case appIntent
    case shortcut
    case shareSheet
    case journalingSuggestion

    var id: String { rawValue }
}

struct ExternalCaptureRequest: Codable, Hashable, Sendable {
    var sourceKind: ExternalCaptureSourceKind
    var title: String?
    var text: String
    var url: String?
    var context: String?
    var affectDrafts: [AffectSnapshotDraft]

    init(
        sourceKind: ExternalCaptureSourceKind,
        title: String? = nil,
        text: String,
        url: String? = nil,
        context: String? = nil,
        affectDrafts: [AffectSnapshotDraft] = []
    ) {
        self.sourceKind = sourceKind
        self.title = title
        self.text = text
        self.url = url
        self.context = context
        self.affectDrafts = affectDrafts
    }
}

struct ExternalCaptureDraftFactory: Sendable {
    func makeDraft(from request: ExternalCaptureRequest) -> MemoryCaptureDraft {
        var artifacts: [CaptureArtifactDraft] = [
            .text(title: request.title, body: request.text, origin: .imported)
        ]
        if let url = request.url?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            artifacts.append(.link(title: request.title, url: url, note: request.text, origin: .imported))
        }
        return MemoryCaptureDraft(
            title: request.title,
            rawText: request.text,
            mood: request.affectDrafts.first?.rawInput,
            inputContext: request.context ?? "external capture: \(request.sourceKind.rawValue)",
            captureSource: request.sourceKind == .shareSheet ? .importFile : .composer,
            artifacts: artifacts,
            affectSnapshots: request.affectDrafts
        )
    }
}

struct JournalingSuggestionContextService: Sendable {
    private let capabilityProvider: any JournalingSuggestionCapabilityProviding
    private let affectMapper: AffectSnapshotMapper

    init(
        capabilityProvider: any JournalingSuggestionCapabilityProviding = DefaultJournalingSuggestionCapabilityProvider(),
        affectMapper: AffectSnapshotMapper = AffectSnapshotMapper()
    ) {
        self.capabilityProvider = capabilityProvider
        self.affectMapper = affectMapper
    }

    func availability() -> JournalingSuggestionAvailability {
        guard capabilityProvider.supportsJournalingSuggestions else {
            return JournalingSuggestionAvailability(
                isAvailable: false,
                reason: .unsupportedOS,
                detail: "Journaling Suggestions requires iOS 17.2 or later."
            )
        }
        guard capabilityProvider.hasJournalingSuggestionEntitlement else {
            return JournalingSuggestionAvailability(
                isAvailable: false,
                reason: .missingEntitlement,
                detail: "Current app entitlements do not include com.apple.developer.journal.allow."
            )
        }
        guard capabilityProvider.userEnabledJournalingSuggestions else {
            return JournalingSuggestionAvailability(
                isAvailable: false,
                reason: .disabledByUser,
                detail: "User has disabled Journaling Suggestions for Mory."
            )
        }
        return .available
    }

    func makeCaptureDraft(from suggestion: JournalingSuggestionDraft) -> MemoryCaptureDraft {
        var bodyParts: [String] = []
        if let body = suggestion.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
            bodyParts.append(body)
        }
        if let prompt = suggestion.reflectionPrompt?.trimmingCharacters(in: .whitespacesAndNewlines), !prompt.isEmpty {
            bodyParts.append(prompt)
        }
        if let workout = suggestion.workoutSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !workout.isEmpty {
            bodyParts.append(workout)
        }
        if let song = suggestion.songTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !song.isEmpty {
            let artist = suggestion.artistName?.trimmingCharacters(in: .whitespacesAndNewlines)
            bodyParts.append([song, artist].compactMap { $0 }.joined(separator: " - "))
        }
        if let place = suggestion.locationTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !place.isEmpty {
            bodyParts.append(place)
        }

        let body = bodyParts.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackBody = suggestion.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Journaling suggestion"
        var artifacts: [CaptureArtifactDraft] = [
            .text(
                title: suggestion.title ?? "Journaling Suggestion",
                body: body.isEmpty ? fallbackBody : body,
                origin: .imported
            )
        ]

        if let locationTitle = suggestion.locationTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !locationTitle.isEmpty {
            artifacts.append(
                .location(
                    title: locationTitle,
                    summary: "Selected from Journaling Suggestions",
                    latitude: suggestion.latitude,
                    longitude: suggestion.longitude,
                    origin: .imported
                )
            )
        }

        if let songTitle = suggestion.songTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !songTitle.isEmpty {
            artifacts.append(
                .music(
                    trackName: songTitle,
                    artistName: suggestion.artistName ?? "Unknown Artist",
                    albumName: "",
                    durationSeconds: 0,
                    artworkURL: nil,
                    origin: .imported
                )
            )
        }

        let affectDrafts: [AffectSnapshotDraft]
        if let stateOfMind = suggestion.stateOfMindLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !stateOfMind.isEmpty {
            affectDrafts = [
                affectMapper.draftFromJournalingStateOfMind(
                    label: stateOfMind,
                    valence: suggestion.stateOfMindValence,
                    arousal: suggestion.stateOfMindArousal,
                    dominance: suggestion.stateOfMindDominance
                )
            ]
        } else {
            affectDrafts = []
        }

        return MemoryCaptureDraft(
            title: suggestion.title ?? "Journaling Suggestion",
            rawText: body.isEmpty ? fallbackBody : body,
            mood: suggestion.stateOfMindLabel,
            inputContext: "journalingSuggestion:selectedAt=\(suggestion.createdAt.formatted(.iso8601))",
            captureSource: .composer,
            artifacts: artifacts,
            affectSnapshots: affectDrafts
        )
    }
}
