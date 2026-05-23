import Foundation
import UniformTypeIdentifiers

#if os(iOS) && canImport(JournalingSuggestions)
import HealthKit
import JournalingSuggestions
import _LocationEssentials

@available(iOS 17.2, *)
struct AppleJournalingSuggestionAdapter: Sendable {
    func makeDraft(from suggestion: JournalingSuggestion) async -> JournalingSuggestionDraft {
        async let locations = suggestion.content(forType: JournalingSuggestion.Location.self)
        async let locationGroups = suggestion.content(forType: JournalingSuggestion.LocationGroup.self)
        async let songs = suggestion.content(forType: JournalingSuggestion.Song.self)
        async let workouts = suggestion.content(forType: JournalingSuggestion.Workout.self)
        async let workoutGroups = suggestion.content(forType: JournalingSuggestion.WorkoutGroup.self)
        async let contacts = suggestion.content(forType: JournalingSuggestion.Contact.self)
        async let photos = suggestion.content(forType: JournalingSuggestion.Photo.self)
        async let videos = suggestion.content(forType: JournalingSuggestion.Video.self)
        async let livePhotos = suggestion.content(forType: JournalingSuggestion.LivePhoto.self)
        async let podcasts = suggestion.content(forType: JournalingSuggestion.Podcast.self)
        async let motionActivities = suggestion.content(forType: JournalingSuggestion.MotionActivity.self)

        let resolvedLocations = await locations
        let resolvedLocationGroups = await locationGroups
        let resolvedSongs = await songs
        let resolvedWorkouts = await workouts
        let resolvedWorkoutGroups = await workoutGroups
        let resolvedContacts = await contacts
        let resolvedPhotos = await photos
        let resolvedVideos = await videos
        let resolvedLivePhotos = await livePhotos
        let resolvedPodcasts = await podcasts
        let resolvedMotionActivities = await motionActivities

        var genericMediaTitle: String?
        var genericMediaArtist: String?
        if #available(iOS 18.0, *) {
            let resolvedGenericMedia = await suggestion.content(forType: JournalingSuggestion.GenericMedia.self)
            genericMediaTitle = resolvedGenericMedia.first?.title?.trimmedOrNil
            genericMediaArtist = resolvedGenericMedia.first?.artist?.trimmedOrNil
        }

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
        if !resolvedLivePhotos.isEmpty {
            bodyParts.append("Live Photos: \(resolvedLivePhotos.count)")
        }
        if let podcast = resolvedPodcasts.first {
            bodyParts.append([podcast.episode, podcast.show].compactMap { $0?.trimmedOrNil }.joined(separator: " - "))
        }
        if let genericMedia = [genericMediaTitle, genericMediaArtist]
            .compactMap({ $0 })
            .joined(separator: " - ")
            .trimmedOrNil {
            bodyParts.append(genericMedia)
        }

        let firstLocation = resolvedLocations.first
        let firstSong = resolvedSongs.first
        let locationGroupTitles = resolvedLocationGroups
            .flatMap(\.locations)
            .compactMap(locationTitle)

        var attachments: [ExternalCaptureAttachmentDraft] = []
        attachments += resolvedPhotos.compactMap { photo in
            copyAsset(url: photo.photo, kind: .image, summary: "Journaling photo")
        }
        attachments += resolvedVideos.compactMap { video in
            copyAsset(url: video.url, kind: .video, summary: "Journaling video")
        }
        attachments += resolvedLivePhotos.compactMap { livePhoto in
            copyAsset(url: livePhoto.image, kind: .image, summary: "Journaling Live Photo image")
        }
        attachments += resolvedLivePhotos.compactMap { livePhoto in
            copyAsset(url: livePhoto.video, kind: .video, summary: "Journaling Live Photo video")
        }
        if let songArtwork = firstSong?.artwork {
            attachments.append(contentsOf: [copyAsset(url: songArtwork, kind: .image, summary: "Song artwork")].compactMap { $0 })
        }
        if let podcastArtwork = resolvedPodcasts.first?.artwork {
            attachments.append(contentsOf: [copyAsset(url: podcastArtwork, kind: .image, summary: "Podcast artwork")].compactMap { $0 })
        }

        var reflectionPrompt: String?
        var eventTitle: String?
        var eventPlace: String?
        var eventPosterAttachment: ExternalCaptureAttachmentDraft?
        if #available(iOS 18.0, *) {
            let reflections = await suggestion.content(forType: JournalingSuggestion.Reflection.self)
            reflectionPrompt = reflections.first?.prompt.trimmedOrNil
        }
        if #available(iOS 26.0, *) {
            let eventPosters = await suggestion.content(forType: JournalingSuggestion.EventPoster.self)
            eventTitle = eventPosters.first.map { String($0.title.characters) }?.trimmedOrNil
            eventPlace = eventPosters.first?.placeName?.trimmedOrNil
            if let image = eventPosters.first?.image {
                eventPosterAttachment = copyAsset(url: image, kind: .image, summary: "Journaling event poster")
            }
        }
        if let eventPosterAttachment {
            attachments.append(eventPosterAttachment)
        }

        var stateOfMindLabel: String?
        var stateOfMindLabels: [String] = []
        var stateOfMindAssociations: [String] = []
        var stateOfMindValence: Double?
        var stateOfMindValenceClassification: String?
        var stateOfMindKind: String?
        if #available(iOS 18.0, *) {
            let statesOfMind = await suggestion.content(forType: JournalingSuggestion.StateOfMind.self)
            if let state = statesOfMind.first?.state {
                stateOfMindLabels = state.labels.map(labelName)
                stateOfMindAssociations = state.associations.map(associationName)
                stateOfMindLabel = stateOfMindLabels.first ?? valenceClassificationName(state.valenceClassification)
                stateOfMindValence = state.valence
                stateOfMindValenceClassification = valenceClassificationName(state.valenceClassification)
                stateOfMindKind = stateKindName(state.kind)
            }
        }

        return JournalingSuggestionDraft(
            title: eventTitle ?? suggestion.title.trimmedOrNil,
            body: bodyParts.joined(separator: "\n").trimmedOrNil,
            reflectionPrompt: reflectionPrompt,
            locationTitle: firstLocation.flatMap(locationTitle) ?? eventPlace,
            locationGroupTitles: locationGroupTitles,
            latitude: firstLocation?.location?.coordinate.latitude,
            longitude: firstLocation?.location?.coordinate.longitude,
            songTitle: firstSong?.song?.trimmedOrNil,
            artistName: firstSong?.artist?.trimmedOrNil,
            albumName: firstSong?.album?.trimmedOrNil,
            podcastEpisode: resolvedPodcasts.first?.episode?.trimmedOrNil,
            podcastShow: resolvedPodcasts.first?.show?.trimmedOrNil,
            genericMediaTitle: genericMediaTitle,
            genericMediaArtist: genericMediaArtist,
            contactNames: resolvedContacts.map(\.name),
            workoutSummary: bodyParts.first(where: { $0.localizedCaseInsensitiveContains("workout") }),
            motionActivitySummary: bodyParts.first(where: { $0.localizedCaseInsensitiveContains("motion activity") }),
            attachments: attachments,
            stateOfMindLabel: stateOfMindLabel,
            stateOfMindLabels: stateOfMindLabels,
            stateOfMindAssociations: stateOfMindAssociations,
            stateOfMindValence: stateOfMindValence,
            stateOfMindValenceClassification: stateOfMindValenceClassification,
            stateOfMindKind: stateOfMindKind,
            stateOfMindArousal: nil,
            stateOfMindDominance: nil,
            createdAt: suggestion.date?.start ?? .now
        )
    }

    private func copyAsset(
        url: URL,
        kind: ExternalCaptureAttachmentKind,
        summary: String
    ) -> ExternalCaptureAttachmentDraft? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let filename = url.lastPathComponent.trimmedOrNil ?? "\(kind.rawValue)-\(UUID().uuidString)"
        guard let storedFileName = try? ExternalCaptureAttachmentFileStore().saveData(data, preferredFilename: filename) else {
            return nil
        }
        return ExternalCaptureAttachmentDraft(
            kind: kind,
            filename: filename,
            contentType: contentType(for: url, kind: kind),
            storedFileName: storedFileName,
            summary: summary
        )
    }

    private func contentType(for url: URL, kind: ExternalCaptureAttachmentKind) -> String {
        if let type = UTType(filenameExtension: url.pathExtension) {
            return type.preferredMIMEType ?? type.identifier
        }
        switch kind {
        case .image:
            return UTType.jpeg.identifier
        case .video:
            return "video/quicktime"
        }
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

    @available(iOS 18.0, *)
    private func associationName(_ association: HKStateOfMind.Association) -> String {
        switch association {
        case .community: "community"
        case .currentEvents: "current events"
        case .dating: "dating"
        case .education: "education"
        case .family: "family"
        case .fitness: "fitness"
        case .friends: "friends"
        case .health: "health"
        case .hobbies: "hobbies"
        case .identity: "identity"
        case .money: "money"
        case .partner: "partner"
        case .selfCare: "self care"
        case .spirituality: "spirituality"
        case .tasks: "tasks"
        case .travel: "travel"
        case .work: "work"
        case .weather: "weather"
        @unknown default: String(describing: association)
        }
    }

    @available(iOS 18.0, *)
    private func stateKindName(_ kind: HKStateOfMind.Kind) -> String {
        switch kind {
        case .momentaryEmotion: "momentary emotion"
        case .dailyMood: "daily mood"
        @unknown default: String(describing: kind)
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
