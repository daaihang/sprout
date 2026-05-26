import Foundation

enum MemoryRepositoryError: LocalizedError, Equatable {
    case recordNotFound(UUID)
    case artifactNotFound(UUID)
    case artifactDoesNotBelongToRecord(artifactID: UUID, recordID: UUID)
    case invalidArtifactOrder(recordID: UUID)
    case externalCaptureInboxItemNotFound(UUID)
    case reflectionNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case let .recordNotFound(id):
            "Memory record was not found: \(id.uuidString)."
        case let .artifactNotFound(id):
            "Memory artifact was not found: \(id.uuidString)."
        case let .artifactDoesNotBelongToRecord(artifactID, recordID):
            "Artifact \(artifactID.uuidString) does not belong to record \(recordID.uuidString)."
        case let .invalidArtifactOrder(recordID):
            "Artifact order contains unknown artifacts for record \(recordID.uuidString)."
        case let .externalCaptureInboxItemNotFound(id):
            "External capture inbox item was not found: \(id.uuidString)."
        case let .reflectionNotFound(id):
            "Reflection was not found: \(id.uuidString)."
        }
    }
}
