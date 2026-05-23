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
        var evidenceItems: [ExternalCaptureEvidenceItem] = []
        var diagnostics: [String] = []
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
            evidenceItems.append(ExternalCaptureEvidenceItem(kind: .photo, title: "Photo", startedAt: photo.date))
            return copyAsset(url: photo.photo, kind: .image, summary: "Journaling photo", diagnostics: &diagnostics)
        }
        attachments += resolvedVideos.compactMap { video in
            evidenceItems.append(ExternalCaptureEvidenceItem(kind: .video, title: "Video", startedAt: video.date))
            return copyAsset(url: video.url, kind: .video, summary: "Journaling video", diagnostics: &diagnostics)
        }
        attachments += resolvedLivePhotos.compactMap { livePhoto in
            evidenceItems.append(ExternalCaptureEvidenceItem(kind: .livePhoto, title: "Live Photo", startedAt: livePhoto.date))
            return copyAsset(url: livePhoto.image, kind: .image, summary: "Journaling Live Photo image", diagnostics: &diagnostics)
        }
        attachments += resolvedLivePhotos.compactMap { livePhoto in
            copyAsset(url: livePhoto.video, kind: .video, summary: "Journaling Live Photo video", diagnostics: &diagnostics)
        }
        if let songArtwork = firstSong?.artwork {
            attachments.append(contentsOf: [copyAsset(url: songArtwork, kind: .image, summary: "Song artwork", diagnostics: &diagnostics)].compactMap { $0 })
        }
        if let podcastArtwork = resolvedPodcasts.first?.artwork {
            attachments.append(contentsOf: [copyAsset(url: podcastArtwork, kind: .image, summary: "Podcast artwork", diagnostics: &diagnostics)].compactMap { $0 })
        }
        if #available(iOS 18.0, *) {
            let genericMedia = await suggestion.content(forType: JournalingSuggestion.GenericMedia.self)
            if let appIcon = genericMedia.first?.appIcon {
                attachments.append(contentsOf: [copyAsset(url: appIcon, kind: .image, summary: "Media app icon", diagnostics: &diagnostics)].compactMap { $0 })
            }
        }
        for contact in resolvedContacts {
            evidenceItems.append(ExternalCaptureEvidenceItem(kind: .contact, title: contact.name))
            if let photo = contact.photo {
                attachments.append(contentsOf: [copyAsset(url: photo, kind: .image, summary: "Contact photo: \(contact.name)", diagnostics: &diagnostics)].compactMap { $0 })
            }
        }
        for location in resolvedLocations {
            evidenceItems.append(ExternalCaptureEvidenceItem(
                kind: .location,
                title: locationTitle(location),
                startedAt: location.date,
                metadata: [
                    "latitude": location.location.map { String($0.coordinate.latitude) } ?? "",
                    "longitude": location.location.map { String($0.coordinate.longitude) } ?? "",
                    "city": location.city ?? "",
                    "place": location.place ?? "",
                    "isWorkLocation": {
                        if #available(iOS 26.0, *) {
                            return location.isWorkLocation.map(String.init) ?? ""
                        }
                        return ""
                    }()
                ].filter { !$0.value.isEmpty }
            ))
        }
        if !locationGroupTitles.isEmpty {
            evidenceItems.append(ExternalCaptureEvidenceItem(
                kind: .locationGroup,
                title: "Location group",
                value: locationGroupTitles.joined(separator: ", ")
            ))
        }
        for song in resolvedSongs {
            evidenceItems.append(ExternalCaptureEvidenceItem(
                kind: .song,
                title: song.song,
                startedAt: song.date,
                metadata: [
                    "song": song.song ?? "",
                    "artist": song.artist ?? "",
                    "album": song.album ?? ""
                ].filter { !$0.value.isEmpty }
            ))
        }
        for podcast in resolvedPodcasts {
            evidenceItems.append(ExternalCaptureEvidenceItem(
                kind: .podcast,
                title: podcast.episode,
                startedAt: podcast.date,
                metadata: [
                    "show": podcast.show ?? ""
                ].filter { !$0.value.isEmpty }
            ))
        }
        if #available(iOS 18.0, *) {
            let genericMedia = await suggestion.content(forType: JournalingSuggestion.GenericMedia.self)
            for media in genericMedia {
                evidenceItems.append(ExternalCaptureEvidenceItem(
                    kind: .genericMedia,
                    title: media.title,
                    startedAt: media.date,
                    metadata: [
                        "artist": media.artist ?? "",
                        "album": media.album ?? ""
                    ].filter { !$0.value.isEmpty }
                ))
            }
        }
        for workout in resolvedWorkouts {
            if let summary = workoutSummary(workout) {
                evidenceItems.append(ExternalCaptureEvidenceItem(
                    kind: .workout,
                    title: "Workout",
                    summary: summary,
                    startedAt: workout.details?.date?.start,
                    endedAt: workout.details?.date?.end,
                    metadata: workoutMetadata(workout)
                ))
            }
            if let icon = workout.icon {
                attachments.append(contentsOf: [copyAsset(url: icon, kind: .image, summary: "Workout icon", diagnostics: &diagnostics)].compactMap { $0 })
            }
        }
        for group in resolvedWorkoutGroups {
            if let summary = workoutGroupSummary(group) {
                evidenceItems.append(ExternalCaptureEvidenceItem(
                    kind: .workoutGroup,
                    title: "Workout group",
                    summary: summary,
                    metadata: [
                        "duration": group.duration.map(String.init) ?? "",
                        "workoutCount": String(group.workouts.count)
                    ].filter { !$0.value.isEmpty }
                ))
            }
            if let icon = group.icon {
                attachments.append(contentsOf: [copyAsset(url: icon, kind: .image, summary: "Workout group icon", diagnostics: &diagnostics)].compactMap { $0 })
            }
        }
        for activity in resolvedMotionActivities {
            if let summary = motionActivitySummary(activity) {
                evidenceItems.append(ExternalCaptureEvidenceItem(
                    kind: .motionActivity,
                    title: "Motion activity",
                    summary: summary,
                    startedAt: activity.date?.start,
                    endedAt: activity.date?.end,
                    metadata: motionActivityMetadata(activity)
                ))
            }
            if let icon = activity.icon {
                attachments.append(contentsOf: [copyAsset(url: icon, kind: .image, summary: "Motion activity icon", diagnostics: &diagnostics)].compactMap { $0 })
            }
        }

        var reflectionPrompt: String?
        var eventTitle: String?
        var eventPlace: String?
        var eventPosterAttachment: ExternalCaptureAttachmentDraft?
        if #available(iOS 18.0, *) {
            let reflections = await suggestion.content(forType: JournalingSuggestion.Reflection.self)
            reflectionPrompt = reflections.first?.prompt.trimmedOrNil
            for reflection in reflections {
                evidenceItems.append(ExternalCaptureEvidenceItem(
                    kind: .reflection,
                    title: "Reflection prompt",
                    value: reflection.prompt
                ))
            }
        }
        if #available(iOS 26.0, *) {
            let eventPosters = await suggestion.content(forType: JournalingSuggestion.EventPoster.self)
            eventTitle = eventPosters.first.map { String($0.title.characters) }?.trimmedOrNil
            eventPlace = eventPosters.first?.placeName?.trimmedOrNil
            if let image = eventPosters.first?.image {
                eventPosterAttachment = copyAsset(url: image, kind: .image, summary: "Journaling event poster", diagnostics: &diagnostics)
            }
            for poster in eventPosters {
                evidenceItems.append(ExternalCaptureEvidenceItem(
                    kind: .eventPoster,
                    title: String(poster.title.characters).trimmedOrNil,
                    startedAt: poster.eventStart,
                    endedAt: poster.eventEnd,
                    metadata: [
                        "placeName": poster.placeName ?? "",
                        "isHost": poster.isHost.map(String.init) ?? ""
                    ].filter { !$0.value.isEmpty }
                ))
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
        var affectEvidence: [ExternalCaptureAffectEvidence] = []
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
            for stateOfMind in statesOfMind {
                let labels = stateOfMind.state.labels.map(labelName)
                let associations = stateOfMind.state.associations.map(associationName)
                let classification = valenceClassificationName(stateOfMind.state.valenceClassification)
                let kind = stateKindName(stateOfMind.state.kind)
                affectEvidence.append(ExternalCaptureAffectEvidence(
                    source: .journalSuggestionStateOfMind,
                    label: labels.first ?? classification,
                    labels: labels,
                    associations: associations,
                    valence: stateOfMind.state.valence,
                    valenceClassification: classification,
                    kind: kind,
                    rawInput: labels.first ?? classification,
                    confidence: 0.9,
                    userConfirmed: true
                ))
                evidenceItems.append(ExternalCaptureEvidenceItem(
                    kind: .stateOfMind,
                    title: labels.first ?? classification,
                    value: classification,
                    metadata: [
                        "labels": labels.joined(separator: ","),
                        "associations": associations.joined(separator: ","),
                        "valence": String(stateOfMind.state.valence),
                        "classification": classification,
                        "kind": kind
                    ].filter { !$0.value.isEmpty }
                ))
            }
        }

        return JournalingSuggestionDraft(
            title: eventTitle ?? suggestion.title.trimmedOrNil,
            body: bodyParts.joined(separator: "\n").trimmedOrNil,
            evidenceItems: evidenceItems,
            affectEvidence: affectEvidence,
            attachments: attachments,
            createdAt: suggestion.date?.start ?? .now,
            diagnostics: diagnostics
        )
    }

    private func copyAsset(
        url: URL,
        kind: ExternalCaptureAttachmentKind,
        summary: String,
        diagnostics: inout [String]
    ) -> ExternalCaptureAttachmentDraft? {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            diagnostics.append("Unable to read \(summary): \(error.localizedDescription)")
            return nil
        }
        let filename = url.lastPathComponent.trimmedOrNil ?? "\(kind.rawValue)-\(UUID().uuidString)"
        let storedFileName: String
        do {
            storedFileName = try ExternalCaptureAttachmentFileStore().saveData(data, preferredFilename: filename)
        } catch {
            diagnostics.append("Unable to store \(summary): \(error.localizedDescription)")
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

    private func workoutMetadata(_ workout: JournalingSuggestion.Workout) -> [String: String] {
        guard let details = workout.details else {
            return ["routePointCount": workout.route.map { String($0.count) } ?? ""].filter { !$0.value.isEmpty }
        }
        var metadata: [String: String] = [
            "activityType": String(describing: details.activityType),
            "routePointCount": workout.route.map { String($0.count) } ?? ""
        ]
        if let distance = details.distance {
            metadata["distanceMeters"] = String(distance.doubleValue(for: .meter()))
        }
        if let energy = details.activeEnergyBurned {
            metadata["activeEnergyKcal"] = String(energy.doubleValue(for: .kilocalorie()))
        }
        if let heartRate = details.averageHeartRate {
            metadata["averageHeartRate"] = String(heartRate.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
        }
        if #available(iOS 26.0, *), let localizedName = details.localizedName {
            metadata["localizedName"] = localizedName
        }
        return metadata.filter { !$0.value.isEmpty }
    }

    private func motionActivityMetadata(_ activity: JournalingSuggestion.MotionActivity) -> [String: String] {
        var metadata = ["steps": String(activity.steps)]
        if #available(iOS 18.0, *), let movementType = activity.movementType {
            metadata["movementType"] = String(describing: movementType)
        }
        return metadata
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
