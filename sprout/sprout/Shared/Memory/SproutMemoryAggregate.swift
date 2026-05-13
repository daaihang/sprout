import Foundation

struct SproutMemoryAggregate: Sendable {
    var recordShell: RecordShell
    var artifacts: [Artifact]
    var knownEntities: [EntityReference]
}
