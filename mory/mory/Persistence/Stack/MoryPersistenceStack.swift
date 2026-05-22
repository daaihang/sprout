import Foundation
import SwiftData

enum MoryLocalDataScope: Hashable, Sendable {
    case legacy
    case owner(String)

    var label: String {
        switch self {
        case .legacy:
            return "legacy"
        case let .owner(ownerID):
            return "owner:\(ownerID)"
        }
    }
}

enum MoryUserDefaultsScopeKind: String, Hashable, Sendable {
    case device
    case owner
    case debug
}

struct MoryUserDefaultsScopeEntry: Identifiable, Hashable, Sendable {
    let key: String
    let scope: MoryUserDefaultsScopeKind
    let note: String

    var id: String { key }
}

struct MoryLocalDataDiagnostics: Hashable, Sendable {
    let ownerID: String
    let scopeLabel: String
    let storeURLDescription: String
    let legacyOwnerID: String?
    let legacyStoreHasUserData: Bool
    let userDefaultsScopes: [MoryUserDefaultsScopeEntry]
}

@MainActor
struct MoryPersistenceStack {
    static let schema = Schema([
        UserSettingsPreferenceStore.self,
        MemoryDetailPresentationPreferenceStore.self,
        QualityTuningPreferenceStore.self,
        HomeBoardPreferenceStore.self,
        IntelligencePreferenceStore.self,
        SelfProfileStore.self,
        CorrectionEventStore.self,
        EntityTombstoneStore.self,
        EntityProfileStore.self,
        PersonProfileStore.self,
        PlaceProfileStore.self,
        ClarificationQuestionStore.self,
        IntelligenceJobStore.self,
        GraphDeltaStore.self,
        HomeBoardSignalStore.self,
        NotificationIntentStore.self,
        RecordShellStore.self,
        ArtifactStore.self,
        BoardStore.self,
        CompositionStore.self,
        CompositionItemStore.self,
        EntityNodeStore.self,
        EntityEdgeStore.self,
        ArtifactEntityLinkStore.self,
        RecordAnalysisSnapshotStore.self,
        MemoryPipelineStatusStore.self,
        ReflectionSnapshotStore.self,
        TemporalArcStore.self,
    ])

    static func makeSharedModelContainer(
        inMemory: Bool = false,
        scope: MoryLocalDataScope = .legacy,
        baseDirectory: URL? = nil
    ) -> ModelContainer {
        do {
            return try makeModelContainer(inMemory: inMemory, scope: scope, baseDirectory: baseDirectory)
        } catch {
            fatalError("Failed to create Mory model container: \(error)")
        }
    }

    static func makeModelContainer(
        inMemory: Bool = false,
        scope: MoryLocalDataScope = .legacy,
        baseDirectory: URL? = nil
    ) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                "MoryV1",
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else if let url = try storeURL(for: scope, baseDirectory: baseDirectory) {
            configuration = ModelConfiguration(
                "MoryV1",
                schema: schema,
                url: url
            )
        } else {
            configuration = ModelConfiguration(
                "MoryV1",
                schema: schema
            )
        }

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func storeURL(for scope: MoryLocalDataScope, baseDirectory: URL? = nil) throws -> URL? {
        switch scope {
        case .legacy where baseDirectory == nil:
            return nil
        case .legacy:
            return try storeURL(directoryName: "legacy", baseDirectory: baseDirectory)
        case let .owner(ownerID):
            return try storeURL(directoryName: ownerStorageDirectoryName(ownerID), baseDirectory: baseDirectory)
        }
    }

    private static func storeURL(directoryName: String, baseDirectory: URL?) throws -> URL {
        let rootDirectory = try localDataRootDirectory(baseDirectory: baseDirectory)
        let directory = rootDirectory.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("MoryV1.store")
    }

    private static func localDataRootDirectory(baseDirectory: URL?) throws -> URL {
        if let baseDirectory {
            try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            return baseDirectory
        }
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = applicationSupport
            .appendingPathComponent("Mory", isDirectory: true)
            .appendingPathComponent("LocalData", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func ownerStorageDirectoryName(_ ownerID: String) -> String {
        let sanitized = ownerID.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "_"
        }.joined()
        let limited = String(sanitized.prefix(48)).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let prefix = limited.isEmpty ? "owner" : limited
        return "\(prefix)-\(stableHashHex(ownerID))"
    }

    static func stableHashHex(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
