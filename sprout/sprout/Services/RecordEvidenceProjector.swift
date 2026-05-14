import Foundation
import UIKit

@MainActor
struct RecordEvidenceProjector {
    struct Projection {
        var recordID: UUID
        var recordShell: RecordShell?
        var artifacts: [Artifact]
        var analysis: RecordAnalysisSnapshot?
        var linkedEntities: [EntityNode]
        var primaryKind: MemoryPresentationKind
        var preferredFocusedSection: RecordSection
        var headlineText: String
        var supportingText: String?
        var metaLabels: [String]
        var weatherCondition: WeatherCondition?
        var mood: MoodType?
        var primaryPersonName: String?
        var primaryPersonInitials: String?
        var photoPreviewImage: UIImage?
        var photoCount: Int
        var linkedLocationName: String?
    }

    private let localization: AppLocalization

    init(localization: AppLocalization) {
        self.localization = localization
    }

    func project(record: Record, memoryView: SproutMemoryRepository.RecordMemoryView?) -> Projection {
        let artifacts: [Artifact] = (memoryView?.artifacts ?? []).sorted(by: artifactSort)
        let analysis = memoryView?.analysis
        let linkedEntities = memoryView?.linkedEntities ?? []

        let textArtifact = firstArtifact(.text, in: artifacts)
        let photoArtifacts = artifacts.filter { $0.kind == .photo }
        let audioArtifact = firstArtifact(.audio, in: artifacts)
        let musicArtifact = firstArtifact(.music, in: artifacts)
        let linkArtifact = firstArtifact(.link, in: artifacts)
        let todoArtifact = firstArtifact(.todo, in: artifacts)
        let locationArtifact = firstArtifact(.location, in: artifacts)
        let weatherArtifact = firstArtifact(.weather, in: artifacts)
        let personArtifact = firstArtifact(.personMention, in: artifacts)

        let primaryKind = resolvePrimaryKind(
            record: record,
            textArtifact: textArtifact,
            photoArtifacts: photoArtifacts,
            audioArtifact: audioArtifact,
            musicArtifact: musicArtifact,
            linkArtifact: linkArtifact,
            todoArtifact: todoArtifact,
            locationArtifact: locationArtifact,
            weatherArtifact: weatherArtifact,
            personArtifact: personArtifact
        )

        let preferredFocusedSection = focusedSection(for: primaryKind, hasText: textArtifact != nil)
        let photoPreviewImage = resolvePhotoPreviewImage(record: record, photoArtifacts: photoArtifacts)
        let photoCount = photoArtifacts.count

        let weatherCondition = resolveWeatherCondition(from: weatherArtifact, record: record)
        let mood = MoodType(rawValue: record.mood ?? "")
        let primaryPersonName = resolvePrimaryPersonName(
            personArtifact: personArtifact,
            linkedEntities: linkedEntities,
            record: record
        )
        let primaryPersonInitials = primaryPersonName.map(initials(from:))
        let linkedLocationName = resolveLocationName(locationArtifact: locationArtifact, record: record)

        return Projection(
            recordID: record.id,
            recordShell: memoryView?.recordShell,
            artifacts: artifacts,
            analysis: analysis,
            linkedEntities: linkedEntities,
            primaryKind: primaryKind,
            preferredFocusedSection: preferredFocusedSection,
            headlineText: resolveHeadline(
                record: record,
                textArtifact: textArtifact,
                audioArtifact: audioArtifact,
                todoArtifact: todoArtifact,
                musicArtifact: musicArtifact,
                weatherArtifact: weatherArtifact,
                locationArtifact: locationArtifact,
                primaryPersonName: primaryPersonName,
                photoCount: photoCount
            ),
            supportingText: resolveSupportingText(
                record: record,
                audioArtifact: audioArtifact,
                todoArtifact: todoArtifact,
                musicArtifact: musicArtifact
            ),
            metaLabels: resolveMetaLabels(
                record: record,
                artifacts: artifacts,
                linkedLocationName: linkedLocationName
            ),
            weatherCondition: weatherCondition,
            mood: mood,
            primaryPersonName: primaryPersonName,
            primaryPersonInitials: primaryPersonInitials,
            photoPreviewImage: photoPreviewImage,
            photoCount: photoCount,
            linkedLocationName: linkedLocationName
        )
    }

    private func resolvePrimaryKind(
        record: Record,
        textArtifact: Artifact?,
        photoArtifacts: [Artifact],
        audioArtifact: Artifact?,
        musicArtifact: Artifact?,
        linkArtifact: Artifact?,
        todoArtifact: Artifact?,
        locationArtifact: Artifact?,
        weatherArtifact: Artifact?,
        personArtifact: Artifact?
    ) -> MemoryPresentationKind {
        if !photoArtifacts.isEmpty { return .photo }
        if musicArtifact != nil { return .music }
        if audioArtifact != nil { return .audio }
        if todoArtifact != nil { return .todo }
        if linkArtifact != nil { return .link }
        if locationArtifact != nil || (record.latitude != nil && record.longitude != nil) { return .map }
        if record.activity?.value != nil { return .activity }
        if let mood = record.mood, !mood.isEmpty { return .emotion }
        if weatherArtifact != nil || !(record.weather ?? "").isEmpty { return .weather }
        if personArtifact != nil || !(record.mentionedPeople ?? []).isEmpty { return .people }
        if textArtifact != nil { return .text }
        return .text
    }

    private func focusedSection(for primaryKind: MemoryPresentationKind, hasText: Bool) -> RecordSection {
        if hasText {
            return .text
        }

        switch primaryKind {
        case .photo:
            return .photo
        case .music:
            return .music
        case .audio:
            return .audio
        case .todo:
            return .todo
        case .link:
            return .link
        case .map:
            return .map
        case .activity:
            return .activity
        case .emotion:
            return .emotion
        case .weather:
            return .weather
        case .people:
            return .people
        case .text, .quote, .todayInHistory, .book, .film, .game, .ticket, .health:
            return .text
        }
    }

    private func resolveHeadline(
        record: Record,
        textArtifact: Artifact?,
        audioArtifact: Artifact?,
        todoArtifact: Artifact?,
        musicArtifact: Artifact?,
        weatherArtifact: Artifact?,
        locationArtifact: Artifact?,
        primaryPersonName: String?,
        photoCount: Int
    ) -> String {
        if let text = nonEmpty(textArtifact?.textContent) ?? nonEmpty(record.body) {
            return text
        }

        if let transcript = nonEmpty(audioArtifact?.textContent) {
            return transcript
        }

        if let todo = todoPayload(from: todoArtifact) {
            if let title = nonEmpty(todo.title) {
                return title
            }
            if let firstItem = todo.items.first?.text, !firstItem.isEmpty {
                return firstItem
            }
        }

        if let title = nonEmpty(musicArtifact?.title) {
            return title
        }

        if let mood = MoodType(rawValue: record.mood ?? "") {
            return mood.label
        }

        if let weatherCondition = resolveWeatherCondition(from: weatherArtifact, record: record) {
            let temperature = resolveWeatherTemperature(from: weatherArtifact, record: record)
            let tempPrefix = temperature.map { "\(Int($0))° " } ?? ""
            return "\(tempPrefix)\(weatherCondition.label)"
        }

        if let location = nonEmpty(locationArtifact?.title) ?? nonEmpty(record.location) {
            return location
        }

        if let primaryPersonName {
            return primaryPersonName
        }

        if photoCount > 0 {
            return localization.string("timeline.photo.count", default: "%d photos", arguments: [photoCount])
        }

        return localization.string("detail.navigation.record", default: "Entry")
    }

    private func resolveSupportingText(
        record: Record,
        audioArtifact: Artifact?,
        todoArtifact: Artifact?,
        musicArtifact: Artifact?
    ) -> String? {
        if let todo = todoPayload(from: todoArtifact) {
            let remaining = todo.items.filter { !$0.isDone }.count
            return localization.string(
                "timeline.todo.summary",
                default: "%d items · %d remaining",
                arguments: [todo.items.count, remaining]
            )
        }

        if let musicArtifact {
            let artist = trimmed(musicArtifact.summary)
            let album = trimmed(musicArtifact.metadata["albumName"] ?? musicArtifact.textContent)
            let components = [artist, album].filter { !$0.isEmpty }
            if !components.isEmpty {
                return components.joined(separator: " · ")
            }
        }

        if let audioArtifact {
            let data = audioArtifact.binaryPayload
            let duration = audioDurationString(from: data)
            if !duration.isEmpty {
                return localization.string("timeline.audio.summary", default: "Voice note · %@", arguments: [duration])
            }
        }

        return nil
    }

    private func resolveMetaLabels(record: Record, artifacts: [Artifact], linkedLocationName: String?) -> [String] {
        var labels: [String] = []

        if artifacts.contains(where: { $0.kind == .text }) {
            labels.append(localization.string("timeline.category.note", default: "Note"))
        }
        if artifacts.contains(where: { $0.kind == .photo }) {
            labels.append(localization.string("timeline.category.photo", default: "Photo"))
        }
        if artifacts.contains(where: { $0.kind == .music }) {
            labels.append(localization.string("timeline.category.music", default: "Music"))
        }
        if artifacts.contains(where: { $0.kind == .audio }) {
            labels.append(localization.string("timeline.category.audio", default: "Voice"))
        }
        if artifacts.contains(where: { $0.kind == .todo }) {
            labels.append(localization.string("timeline.category.todo", default: "To-Do"))
        }
        if artifacts.contains(where: { $0.kind == .link }) {
            labels.append(localization.string("timeline.category.link", default: "Link"))
        }
        if artifacts.contains(where: { $0.kind == .weather }) || !(record.weather ?? "").isEmpty {
            labels.append(localization.string("timeline.category.weather", default: "Weather"))
        }
        if record.mood != nil {
            labels.append(localization.string("timeline.category.emotion", default: "Emotion"))
        }
        if artifacts.contains(where: { $0.kind == .location }) || record.latitude != nil {
            labels.append(localization.string("timeline.category.location", default: "Location"))
        }
        if artifacts.contains(where: { $0.kind == .personMention }) || !(record.mentionedPeople ?? []).isEmpty {
            labels.append(localization.string("timeline.category.people", default: "People"))
        }

        if let linkedLocationName, !linkedLocationName.isEmpty {
            labels.append(linkedLocationName)
        }

        return Array(labels.prefix(3))
    }

    private func resolveWeatherCondition(from artifact: Artifact?, record: Record) -> WeatherCondition? {
        if let artifact,
           let condition = WeatherCondition(rawValue: artifact.metadata["condition"] ?? artifact.title) {
            return condition
        }
        return (record.weather).flatMap(WeatherCondition.init(rawValue:))
    }

    private func resolveWeatherTemperature(from artifact: Artifact?, record: Record) -> Double? {
        if let artifact,
           let value = Double(artifact.metadata["temperature"] ?? "") {
            return value
        }
        return record.temperature
    }

    private func resolvePrimaryPersonName(
        personArtifact: Artifact?,
        linkedEntities: [EntityNode],
        record: Record
    ) -> String? {
        if let title = nonEmpty(personArtifact?.title) {
            return title
        }
        if let linkedPerson = linkedEntities.first(where: { $0.kind == .person }),
           !linkedPerson.displayName.isEmpty {
            return linkedPerson.displayName
        }
        return record.mentionedPeople?.first?.displayName
    }

    private func resolveLocationName(locationArtifact: Artifact?, record: Record) -> String? {
        if let title = nonEmpty(locationArtifact?.title) {
            return title
        }
        return nonEmpty(record.location)
    }

    private func resolvePhotoPreviewImage(record: Record, photoArtifacts: [Artifact]) -> UIImage? {
        if let data = photoArtifacts.first?.previewPayload ?? photoArtifacts.first?.binaryPayload {
            return UIImage(data: data)
        }
        return nil
    }

    private func todoPayload(from artifact: Artifact?) -> (title: String, items: [TodoItem])? {
        guard let artifact else { return nil }
        let items = decodeTodoItems(from: artifact.textContent)
        guard !items.isEmpty else { return nil }
        return (artifact.title, items)
    }

    private func firstArtifact(_ kind: ArtifactKind, in artifacts: [Artifact]) -> Artifact? {
        artifacts.first { $0.kind == kind }
    }

    private func decodeTodoItems(from text: String) -> [TodoItem] {
        guard let raw = text.data(using: .utf8),
              let items = try? JSONDecoder().decode([TodoItem].self, from: raw) else {
            return []
        }
        return items
    }

    private func initials(from name: String) -> String {
        let components = name
            .split(whereSeparator: { $0 == " " || $0 == "-" })
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
        return components.isEmpty ? String(name.prefix(1)).uppercased() : components.joined()
    }

    private func nonEmpty(_ value: String?) -> String? {
        let trimmed = trimmed(value)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func trimmed(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func artifactSort(lhs: Artifact, rhs: Artifact) -> Bool {
        if lhs.createdAt == rhs.createdAt {
            return lhs.updatedAt < rhs.updatedAt
        }
        return lhs.createdAt < rhs.createdAt
    }
}
