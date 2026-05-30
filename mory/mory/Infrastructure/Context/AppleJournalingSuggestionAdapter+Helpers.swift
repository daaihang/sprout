import Foundation
import UniformTypeIdentifiers

#if os(iOS) && canImport(JournalingSuggestions)
import HealthKit
import JournalingSuggestions
import _LocationEssentials

@available(iOS 17.2, *)
extension AppleJournalingSuggestionAdapter {
    func copyAsset(
        url: URL,
        kind: ExternalCaptureAttachmentKind,
        role: ExternalCaptureAttachmentRole = .primaryMedia,
        referenceID: UUID? = nil,
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
            role: role,
            referenceID: referenceID,
            filename: filename,
            contentType: contentType(for: url, kind: kind),
            storedFileName: storedFileName,
            summary: summary
        )
    }

    func workoutMetadata(_ workout: JournalingSuggestion.Workout) -> [String: String] {
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

    func motionActivityMetadata(_ activity: JournalingSuggestion.MotionActivity) -> [String: String] {
        var metadata = ["steps": String(activity.steps)]
        if #available(iOS 18.0, *), let movementType = activity.movementType {
            metadata["movementType"] = String(describing: movementType)
        }
        return metadata
    }

    func contentType(for url: URL, kind: ExternalCaptureAttachmentKind) -> String {
        if let type = UTType(filenameExtension: url.pathExtension) {
            return type.preferredMIMEType ?? type.identifier
        }
        switch kind {
        case .image:
            return UTType.jpeg.identifier
        case .video:
            return "video/quicktime"
        case .file:
            return "application/octet-stream"
        }
    }

    func locationTitle(_ location: JournalingSuggestion.Location) -> String? {
        [location.place?.trimmedOrNil, location.city?.trimmedOrNil]
            .compactMap { $0 }
            .joined(separator: ", ")
            .trimmedOrNil
    }

    func locationEvidence(_ location: JournalingSuggestion.Location) -> JournalingLocationEvidence {
        var isWorkLocation: Bool?
        if #available(iOS 26.0, *) {
            isWorkLocation = location.isWorkLocation
        }
        return JournalingLocationEvidence(
            title: locationTitle(location),
            place: location.place,
            city: location.city,
            latitude: location.location?.coordinate.latitude,
            longitude: location.location?.coordinate.longitude,
            isWorkLocation: isWorkLocation,
            startedAt: location.date
        )
    }

    func workoutSummary(_ workout: JournalingSuggestion.Workout) -> String? {
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

    func workoutGroupSummary(_ group: JournalingSuggestion.WorkoutGroup) -> String? {
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

    func motionActivitySummary(_ activity: JournalingSuggestion.MotionActivity) -> String? {
        guard activity.steps > 0 else { return nil }
        return "Motion activity · \(activity.steps) steps"
    }

    @available(iOS 18.0, *)
    func labelName(_ label: HKStateOfMind.Label) -> String {
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
    func valenceClassificationName(_ classification: HKStateOfMind.ValenceClassification) -> String {
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
    func associationName(_ association: HKStateOfMind.Association) -> String {
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
    func stateKindName(_ kind: HKStateOfMind.Kind) -> String {
        switch kind {
        case .momentaryEmotion: "momentary emotion"
        case .dailyMood: "daily mood"
        @unknown default: String(describing: kind)
        }
    }

    static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
#endif
