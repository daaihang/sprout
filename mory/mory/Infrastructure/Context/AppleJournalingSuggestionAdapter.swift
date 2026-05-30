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

        var resolvedGenericMedia: [JournalingSuggestion.GenericMedia] = []
        if #available(iOS 18.0, *) {
            resolvedGenericMedia = await suggestion.content(forType: JournalingSuggestion.GenericMedia.self)
        }

        var bodyParts: [String] = []
        var bundle = JournalingEvidenceBundle()
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
        for podcast in resolvedPodcasts {
            if let text = [podcast.episode, podcast.show].compactMap({ $0?.trimmedOrNil }).joined(separator: " - ").trimmedOrNil {
                bodyParts.append(text)
            }
        }
        for media in resolvedGenericMedia {
            if let text = [media.title, media.artist].compactMap({ $0?.trimmedOrNil }).joined(separator: " - ").trimmedOrNil {
                bodyParts.append(text)
            }
        }

        bundle.locations = resolvedLocations.map(locationEvidence)
        bundle.locationGroups = resolvedLocationGroups.map { group in
            group.locations.map(locationEvidence)
        }

        for photo in resolvedPhotos {
            let id = UUID()
            let attachment = copyAsset(url: photo.photo, kind: .image, role: .primaryMedia, referenceID: id, summary: "Journaling photo", diagnostics: &diagnostics)
            bundle.attachments.append(contentsOf: [attachment].compactMap { $0 })
            bundle.photoVideos.append(JournalingPhotoVideoEvidence(id: id, kind: .photo, startedAt: photo.date, attachmentID: attachment?.id))
        }
        for video in resolvedVideos {
            let id = UUID()
            let attachment = copyAsset(url: video.url, kind: .video, role: .primaryMedia, referenceID: id, summary: "Journaling video", diagnostics: &diagnostics)
            bundle.attachments.append(contentsOf: [attachment].compactMap { $0 })
            bundle.photoVideos.append(JournalingPhotoVideoEvidence(id: id, kind: .video, startedAt: video.date, attachmentID: attachment?.id))
        }
        for livePhoto in resolvedLivePhotos {
            let id = UUID()
            let imageAttachment = copyAsset(url: livePhoto.image, kind: .image, role: .primaryMedia, referenceID: id, summary: "Journaling Live Photo still", diagnostics: &diagnostics)
            let videoAttachment = copyAsset(url: livePhoto.video, kind: .video, role: .primaryMedia, referenceID: id, summary: "Journaling Live Photo video", diagnostics: &diagnostics)
            bundle.attachments.append(contentsOf: [videoAttachment].compactMap { $0 })
            bundle.attachments.append(contentsOf: [imageAttachment].compactMap { $0 })
            bundle.photoVideos.append(JournalingPhotoVideoEvidence(
                id: id,
                kind: .livePhoto,
                startedAt: livePhoto.date,
                attachmentID: imageAttachment?.id,
                pairedVideoAttachmentID: videoAttachment?.id
            ))
        }

        for song in resolvedSongs {
            let id = UUID()
            let artwork = song.artwork.flatMap {
                copyAsset(url: $0, kind: .image, role: .artwork, referenceID: id, summary: "Song artwork", diagnostics: &diagnostics)
            }
            bundle.attachments.append(contentsOf: [artwork].compactMap { $0 })
            bundle.media.append(JournalingMediaEvidence(
                id: id,
                kind: .song,
                title: song.song,
                artist: song.artist,
                albumOrShow: song.album,
                startedAt: song.date,
                artworkAttachmentID: artwork?.id,
                metadata: [
                    "song": song.song ?? "",
                    "artist": song.artist ?? "",
                    "album": song.album ?? ""
                ].filter { !$0.value.isEmpty }
            ))
        }

        for podcast in resolvedPodcasts {
            let id = UUID()
            let artwork = podcast.artwork.flatMap {
                copyAsset(url: $0, kind: .image, role: .artwork, referenceID: id, summary: "Podcast artwork", diagnostics: &diagnostics)
            }
            bundle.attachments.append(contentsOf: [artwork].compactMap { $0 })
            bundle.media.append(JournalingMediaEvidence(
                id: id,
                kind: .podcast,
                title: podcast.episode,
                artist: podcast.show,
                albumOrShow: podcast.show,
                startedAt: podcast.date,
                artworkAttachmentID: artwork?.id,
                metadata: ["show": podcast.show ?? ""].filter { !$0.value.isEmpty }
            ))
        }

        for media in resolvedGenericMedia {
            let id = UUID()
            let icon = media.appIcon.flatMap {
                copyAsset(url: $0, kind: .image, role: .icon, referenceID: id, summary: "Media app icon", diagnostics: &diagnostics)
            }
            bundle.attachments.append(contentsOf: [icon].compactMap { $0 })
            bundle.media.append(JournalingMediaEvidence(
                id: id,
                kind: .genericMedia,
                title: media.title,
                artist: media.artist,
                albumOrShow: media.album,
                startedAt: media.date,
                artworkAttachmentID: icon?.id,
                metadata: [
                    "artist": media.artist ?? "",
                    "album": media.album ?? ""
                ].filter { !$0.value.isEmpty }
            ))
        }

        for contact in resolvedContacts {
            let id = UUID()
            let photo = contact.photo.flatMap {
                copyAsset(url: $0, kind: .image, role: .contactPhoto, referenceID: id, summary: "Contact photo: \(contact.name)", diagnostics: &diagnostics)
            }
            bundle.attachments.append(contentsOf: [photo].compactMap { $0 })
            bundle.contacts.append(JournalingContactEvidence(id: id, name: contact.name, photoAttachmentID: photo?.id))
        }

        for workout in resolvedWorkouts {
            if let summary = workoutSummary(workout) {
                let id = UUID()
                let icon = workout.icon.flatMap {
                    copyAsset(url: $0, kind: .image, role: .icon, referenceID: id, summary: "Workout icon", diagnostics: &diagnostics)
                }
                bundle.attachments.append(contentsOf: [icon].compactMap { $0 })
                bundle.activities.append(JournalingActivityEvidence(
                    id: id,
                    kind: .workout,
                    title: "Workout",
                    summary: summary,
                    startedAt: workout.details?.date?.start,
                    endedAt: workout.details?.date?.end,
                    iconAttachmentID: icon?.id,
                    metadata: workoutMetadata(workout)
                ))
            }
        }
        for group in resolvedWorkoutGroups {
            if let summary = workoutGroupSummary(group) {
                let id = UUID()
                let icon = group.icon.flatMap {
                    copyAsset(url: $0, kind: .image, role: .icon, referenceID: id, summary: "Workout group icon", diagnostics: &diagnostics)
                }
                bundle.attachments.append(contentsOf: [icon].compactMap { $0 })
                bundle.activities.append(JournalingActivityEvidence(
                    id: id,
                    kind: .workoutGroup,
                    title: "Workout group",
                    summary: summary,
                    iconAttachmentID: icon?.id,
                    metadata: [
                        "durationSeconds": group.duration.map { String($0) } ?? "",
                        "workoutCount": String(group.workouts.count)
                    ].filter { !$0.value.isEmpty }
                ))
            }
        }
        for activity in resolvedMotionActivities {
            if let summary = motionActivitySummary(activity) {
                let id = UUID()
                let icon = activity.icon.flatMap {
                    copyAsset(url: $0, kind: .image, role: .icon, referenceID: id, summary: "Motion activity icon", diagnostics: &diagnostics)
                }
                bundle.attachments.append(contentsOf: [icon].compactMap { $0 })
                bundle.activities.append(JournalingActivityEvidence(
                    id: id,
                    kind: .motionActivity,
                    title: "Motion activity",
                    summary: summary,
                    startedAt: activity.date?.start,
                    endedAt: activity.date?.end,
                    iconAttachmentID: icon?.id,
                    metadata: motionActivityMetadata(activity)
                ))
            }
        }

        var eventTitle: String?
        if #available(iOS 18.0, *) {
            let reflections = await suggestion.content(forType: JournalingSuggestion.Reflection.self)
            for reflection in reflections {
                bundle.reflections.append(JournalingReflectionEvidence(prompt: reflection.prompt, colorDescription: reflection.color.map { String(describing: $0) }))
            }
        }
        if #available(iOS 26.0, *) {
            let eventPosters = await suggestion.content(forType: JournalingSuggestion.EventPoster.self)
            eventTitle = eventPosters.first.map { String($0.title.characters) }?.trimmedOrNil
            for poster in eventPosters {
                let id = UUID()
                let image = poster.image.flatMap {
                    copyAsset(url: $0, kind: .image, role: .eventPosterImage, referenceID: id, summary: "Journaling event poster", diagnostics: &diagnostics)
                }
                bundle.attachments.append(contentsOf: [image].compactMap { $0 })
                bundle.eventPosters.append(JournalingEventPosterEvidence(
                    id: id,
                    title: String(poster.title.characters).trimmedOrNil,
                    startedAt: poster.eventStart,
                    endedAt: poster.eventEnd,
                    isHost: poster.isHost,
                    placeName: poster.placeName,
                    imageAttachmentID: image?.id
                ))
            }
        }

        if #available(iOS 18.0, *) {
            let statesOfMind = await suggestion.content(forType: JournalingSuggestion.StateOfMind.self)
            for stateOfMind in statesOfMind {
                let labels = stateOfMind.state.labels.map(labelName)
                let associations = stateOfMind.state.associations.map(associationName)
                let classification = valenceClassificationName(stateOfMind.state.valenceClassification)
                let kind = stateKindName(stateOfMind.state.kind)
                bundle.stateOfMind.append(ExternalCaptureAffectEvidence(
                    source: .journalSuggestionStateOfMind,
                    label: labels.first ?? classification,
                    labels: labels,
                    associations: associations,
                    valence: stateOfMind.state.valence,
                    valenceClassification: classification,
                    kind: kind,
                    rawInput: labels.first ?? classification,
                    confidence: 0.9,
                    userConfirmed: true,
                    metadata: [
                        "labels": labels.joined(separator: ","),
                        "associations": associations.joined(separator: ","),
                        "valence": String(stateOfMind.state.valence),
                        "valenceClassification": classification,
                        "kind": kind
                    ].filter { !$0.value.isEmpty }
                ))
            }
        }
        bundle.diagnostics = diagnostics

        return JournalingSuggestionDraft(
            title: eventTitle ?? suggestion.title.trimmedOrNil,
            body: bodyParts.joined(separator: "\n").trimmedOrNil,
            bundle: bundle,
            createdAt: suggestion.date?.start ?? .now,
            diagnostics: []
        )
    }

}
#endif
