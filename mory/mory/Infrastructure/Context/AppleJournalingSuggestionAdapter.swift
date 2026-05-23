import Foundation

#if os(iOS) && canImport(JournalingSuggestions)
import HealthKit
import JournalingSuggestions
import _LocationEssentials

@available(iOS 17.2, *)
struct AppleJournalingSuggestionAdapter: Sendable {
    func makeDraft(from suggestion: JournalingSuggestion) async -> JournalingSuggestionDraft {
        async let locations = suggestion.content(forType: JournalingSuggestion.Location.self)
        async let songs = suggestion.content(forType: JournalingSuggestion.Song.self)
        async let workouts = suggestion.content(forType: JournalingSuggestion.Workout.self)
        async let workoutGroups = suggestion.content(forType: JournalingSuggestion.WorkoutGroup.self)
        async let contacts = suggestion.content(forType: JournalingSuggestion.Contact.self)
        async let photos = suggestion.content(forType: JournalingSuggestion.Photo.self)
        async let videos = suggestion.content(forType: JournalingSuggestion.Video.self)
        async let podcasts = suggestion.content(forType: JournalingSuggestion.Podcast.self)
        async let motionActivities = suggestion.content(forType: JournalingSuggestion.MotionActivity.self)

        let resolvedLocations = await locations
        let resolvedSongs = await songs
        let resolvedWorkouts = await workouts
        let resolvedWorkoutGroups = await workoutGroups
        let resolvedContacts = await contacts
        let resolvedPhotos = await photos
        let resolvedVideos = await videos
        let resolvedPodcasts = await podcasts
        let resolvedMotionActivities = await motionActivities

        var bodyParts: [String] = []
        if !resolvedContacts.isEmpty {
            bodyParts.append("Contacts: \(resolvedContacts.map(\.name).joined(separator: ", "))")
        }
        bodyParts.append(contentsOf: resolvedWorkouts.compactMap(workoutSummary))
        bodyParts.append(contentsOf: resolvedWorkoutGroups.compactMap(workoutGroupSummary))
        bodyParts.append(contentsOf: resolvedMotionActivities.compactMap(motionActivitySummary))
        if !resolvedPhotos.isEmpty {
            bodyParts.append("Photos: \(resolvedPhotos.count)")
        }
        if !resolvedVideos.isEmpty {
            bodyParts.append("Videos: \(resolvedVideos.count)")
        }
        if let podcast = resolvedPodcasts.first {
            bodyParts.append([podcast.episode, podcast.show].compactMap { $0?.trimmedOrNil }.joined(separator: " - "))
        }

        let firstLocation = resolvedLocations.first
        let firstSong = resolvedSongs.first

        var reflectionPrompt: String?
        var eventTitle: String?
        var eventPlace: String?
        if #available(iOS 18.0, *) {
            let reflections = await suggestion.content(forType: JournalingSuggestion.Reflection.self)
            reflectionPrompt = reflections.first?.prompt.trimmedOrNil
        }
        if #available(iOS 26.0, *) {
            let eventPosters = await suggestion.content(forType: JournalingSuggestion.EventPoster.self)
            eventTitle = eventPosters.first.map { String($0.title.characters) }?.trimmedOrNil
            eventPlace = eventPosters.first?.placeName?.trimmedOrNil
        }

        var stateOfMindLabel: String?
        var stateOfMindValence: Double?
        if #available(iOS 18.0, *) {
            let statesOfMind = await suggestion.content(forType: JournalingSuggestion.StateOfMind.self)
            if let state = statesOfMind.first?.state {
                stateOfMindLabel = state.labels.first.map(labelName) ?? valenceClassificationName(state.valenceClassification)
                stateOfMindValence = state.valence
            }
        }

        return JournalingSuggestionDraft(
            title: eventTitle ?? suggestion.title.trimmedOrNil,
            body: bodyParts.joined(separator: "\n").trimmedOrNil,
            reflectionPrompt: reflectionPrompt,
            locationTitle: firstLocation.flatMap(locationTitle) ?? eventPlace,
            latitude: firstLocation?.location?.coordinate.latitude,
            longitude: firstLocation?.location?.coordinate.longitude,
            songTitle: firstSong?.song?.trimmedOrNil,
            artistName: firstSong?.artist?.trimmedOrNil,
            workoutSummary: bodyParts.first(where: { $0.localizedCaseInsensitiveContains("workout") }),
            stateOfMindLabel: stateOfMindLabel,
            stateOfMindValence: stateOfMindValence,
            stateOfMindArousal: nil,
            stateOfMindDominance: nil,
            createdAt: suggestion.date?.start ?? .now
        )
    }

    private func locationTitle(_ location: JournalingSuggestion.Location) -> String? {
        [location.place?.trimmedOrNil, location.city?.trimmedOrNil]
            .compactMap { $0 }
            .joined(separator: ", ")
            .trimmedOrNil
    }

    private func workoutSummary(_ workout: JournalingSuggestion.Workout) -> String? {
        guard let details = workout.details else { return nil }
        var parts: [String] = ["Workout"]
        if #available(iOS 26.0, *), let name = details.localizedName?.trimmedOrNil {
            parts.append(name)
        } else {
            parts.append(String(describing: details.activityType))
        }
        if let distance = details.distance {
            parts.append(String(format: "%.2f km", distance.doubleValue(for: .meterUnit(with: .kilo))))
        }
        if let activeEnergy = details.activeEnergyBurned {
            parts.append(String(format: "%.0f kcal", activeEnergy.doubleValue(for: .kilocalorie())))
        }
        return parts.joined(separator: " · ")
    }

    private func workoutGroupSummary(_ group: JournalingSuggestion.WorkoutGroup) -> String? {
        guard !group.workouts.isEmpty || group.duration != nil else { return nil }
        var parts = ["Workout group"]
        if let duration = group.duration {
            parts.append(Self.durationFormatter.string(from: duration) ?? "\(Int(duration / 60)) min")
        }
        if let activeEnergy = group.activeEnergyBurned {
            parts.append(String(format: "%.0f kcal", activeEnergy.doubleValue(for: .kilocalorie())))
        }
        return parts.joined(separator: " · ")
    }

    private func motionActivitySummary(_ activity: JournalingSuggestion.MotionActivity) -> String? {
        guard activity.steps > 0 else { return nil }
        return "Motion activity · \(activity.steps) steps"
    }

    @available(iOS 18.0, *)
    private func labelName(_ label: HKStateOfMind.Label) -> String {
        switch label {
        case .amazed: "amazed"
        case .amused: "amused"
        case .angry: "angry"
        case .anxious: "anxious"
        case .ashamed: "ashamed"
        case .brave: "brave"
        case .calm: "calm"
        case .content: "content"
        case .disappointed: "disappointed"
        case .discouraged: "discouraged"
        case .disgusted: "disgusted"
        case .embarrassed: "embarrassed"
        case .excited: "excited"
        case .frustrated: "frustrated"
        case .grateful: "grateful"
        case .guilty: "guilty"
        case .happy: "happy"
        case .hopeless: "hopeless"
        case .irritated: "irritated"
        case .jealous: "jealous"
        case .joyful: "joyful"
        case .lonely: "lonely"
        case .passionate: "passionate"
        case .peaceful: "peaceful"
        case .proud: "proud"
        case .relieved: "relieved"
        case .sad: "sad"
        case .scared: "scared"
        case .stressed: "stressed"
        case .surprised: "surprised"
        case .worried: "worried"
        case .annoyed: "annoyed"
        case .confident: "confident"
        case .drained: "drained"
        case .hopeful: "hopeful"
        case .indifferent: "indifferent"
        case .overwhelmed: "overwhelmed"
        case .satisfied: "satisfied"
        @unknown default: String(describing: label)
        }
    }

    @available(iOS 18.0, *)
    private func valenceClassificationName(_ classification: HKStateOfMind.ValenceClassification) -> String {
        switch classification {
        case .veryUnpleasant: "very unpleasant"
        case .unpleasant: "unpleasant"
        case .slightlyUnpleasant: "slightly unpleasant"
        case .neutral: "neutral"
        case .slightlyPleasant: "slightly pleasant"
        case .pleasant: "pleasant"
        case .veryPleasant: "very pleasant"
        @unknown default: String(describing: classification)
        }
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
#endif
