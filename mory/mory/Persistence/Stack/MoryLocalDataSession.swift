import Foundation
import SwiftData

@MainActor
final class LocalDataOwnerRegistry {
    private static let legacyOwnerDefaultsKey = "mory.localData.legacyOwnerID.v1"
    static let activeOwnerDefaultsKey = "mory.localData.lastPreparedOwnerID.v1"

    private let defaults: UserDefaults
    private let baseDirectory: URL?

    init(defaults: UserDefaults = .standard, baseDirectory: URL? = nil) {
        self.defaults = defaults
        self.baseDirectory = baseDirectory
    }

    func scope(for ownerID: String) -> MoryLocalDataScope {
        let normalizedOwnerID = normalized(ownerID)
        if let legacyOwnerID = defaults.string(forKey: Self.legacyOwnerDefaultsKey) {
            return legacyOwnerID == normalizedOwnerID ? .legacy : .owner(normalizedOwnerID)
        }

        guard normalizedOwnerID != AuthCredential.guest.localDataOwnerID else {
            return .owner(normalizedOwnerID)
        }

        if legacyStoreContainsUserData() {
            defaults.set(normalizedOwnerID, forKey: Self.legacyOwnerDefaultsKey)
            return .legacy
        }

        return .owner(normalizedOwnerID)
    }

    func legacyOwnerID() -> String? {
        defaults.string(forKey: Self.legacyOwnerDefaultsKey)
    }

    func activeOwnerID() -> String? {
        defaults.string(forKey: Self.activeOwnerDefaultsKey)
    }

    func activeScopeForExternalCapture() -> MoryLocalDataScope {
        guard let ownerID = activeOwnerID() else { return .legacy }
        return scope(for: ownerID)
    }

    func hasLegacyStoreUserData() -> Bool {
        legacyStoreContainsUserData()
    }

    private func normalized(_ ownerID: String) -> String {
        ownerID.trimmedOrNil ?? "unknown"
    }

    private func legacyStoreContainsUserData() -> Bool {
        do {
            let container = try MoryPersistenceStack.makeModelContainer(
                scope: .legacy,
                baseDirectory: baseDirectory
            )
            let context = container.mainContext
            return try !context.fetch(FetchDescriptor<RecordShellStore>()).isEmpty
                || !context.fetch(FetchDescriptor<ArtifactStore>()).isEmpty
                || !context.fetch(FetchDescriptor<EntityNodeStore>()).isEmpty
                || !context.fetch(FetchDescriptor<ReflectionSnapshotStore>()).isEmpty
                || !context.fetch(FetchDescriptor<UserSettingsPreferenceStore>()).isEmpty
        } catch {
            return false
        }
    }
}

@MainActor
final class MoryLocalDataSession {
    let ownerID: String
    let scope: MoryLocalDataScope
    let modelContainer: ModelContainer
    let memoryRepository: any MoryMemoryRepositorying
    let diagnostics: MoryLocalDataDiagnostics

    convenience init(
        ownerID: String,
        analysisService: any ReflectionAnalysisServing,
        cloudIntelligenceService: (any CloudIntelligenceServing)? = nil,
        notificationOrchestrator: NotificationOrchestrator? = nil
    ) {
        let baseDirectory = Self.testingBaseDirectoryIfNeeded()
        let registry = LocalDataOwnerRegistry(baseDirectory: baseDirectory)
        self.init(
            ownerID: ownerID,
            analysisService: analysisService,
            cloudIntelligenceService: cloudIntelligenceService,
            notificationOrchestrator: notificationOrchestrator,
            scope: registry.scope(for: ownerID),
            baseDirectory: baseDirectory
        )
    }

    init(
        ownerID: String,
        analysisService: any ReflectionAnalysisServing,
        cloudIntelligenceService: (any CloudIntelligenceServing)? = nil,
        notificationOrchestrator: NotificationOrchestrator? = nil,
        registry: LocalDataOwnerRegistry
    ) {
        self.ownerID = ownerID
        self.scope = registry.scope(for: ownerID)
        self.modelContainer = MoryPersistenceStack.makeSharedModelContainer(scope: scope)
        self.memoryRepository = MoryMemoryRepository(
            modelContext: modelContainer.mainContext,
            analysisService: analysisService,
            cloudIntelligenceService: cloudIntelligenceService,
            localDataOwnerID: ownerID,
            notificationOrchestrator: notificationOrchestrator
        )
        self.diagnostics = Self.makeDiagnostics(
            ownerID: ownerID,
            scope: scope,
            baseDirectory: nil,
            registry: registry
        )
    }

    init(
        ownerID: String,
        analysisService: any ReflectionAnalysisServing,
        cloudIntelligenceService: (any CloudIntelligenceServing)? = nil,
        notificationOrchestrator: NotificationOrchestrator? = nil,
        scope: MoryLocalDataScope,
        baseDirectory: URL?
    ) {
        self.ownerID = ownerID
        self.scope = scope
        self.modelContainer = MoryPersistenceStack.makeSharedModelContainer(
            scope: scope,
            baseDirectory: baseDirectory
        )
        self.memoryRepository = MoryMemoryRepository(
            modelContext: modelContainer.mainContext,
            analysisService: analysisService,
            cloudIntelligenceService: cloudIntelligenceService,
            localDataOwnerID: ownerID,
            notificationOrchestrator: notificationOrchestrator
        )
        self.diagnostics = Self.makeDiagnostics(
            ownerID: ownerID,
            scope: scope,
            baseDirectory: baseDirectory,
            registry: LocalDataOwnerRegistry(baseDirectory: baseDirectory)
        )
    }

    private static func makeDiagnostics(
        ownerID: String,
        scope: MoryLocalDataScope,
        baseDirectory: URL?,
        registry: LocalDataOwnerRegistry
    ) -> MoryLocalDataDiagnostics {
        let storeDescription: String
        do {
            storeDescription = try MoryPersistenceStack.storeURL(for: scope, baseDirectory: baseDirectory)?
                .path
                ?? "SwiftData default store"
        } catch {
            storeDescription = "unresolved: \(error.localizedDescription)"
        }

        return MoryLocalDataDiagnostics(
            ownerID: ownerID,
            scopeLabel: scope.label,
            storeURLDescription: storeDescription,
            legacyOwnerID: registry.legacyOwnerID(),
            legacyStoreHasUserData: registry.hasLegacyStoreUserData(),
            userDefaultsScopes: Self.userDefaultsScopes(ownerID: ownerID)
        )
    }

    private static func userDefaultsScopes(ownerID: String) -> [MoryUserDefaultsScopeEntry] {
        [
            MoryUserDefaultsScopeEntry(
                key: "mory.apnsTokenHex",
                scope: .device,
                note: "APNs token is issued per app install/device and shared by all local owners."
            ),
            MoryUserDefaultsScopeEntry(
                key: "mory.remotePush.lastRegistrationDigest.<owner>",
                scope: .owner,
                note: "Remote push registration digest is namespaced to \(ownerID)."
            ),
            MoryUserDefaultsScopeEntry(
                key: "mory.remotePush.pendingWritebacks.<owner>",
                scope: .owner,
                note: "Delivery writeback retry queue is namespaced to \(ownerID)."
            ),
            MoryUserDefaultsScopeEntry(
                key: "mory.onboarding.v1.completed",
                scope: .device,
                note: "Current onboarding completion is device-scoped; no memory data is stored here."
            ),
            MoryUserDefaultsScopeEntry(
                key: "mory.debug.qualityTuning.*",
                scope: .debug,
                note: "Runtime tuning switches are debug/device-scoped; persisted quality preferences live in the owner SwiftData vault."
            ),
            MoryUserDefaultsScopeEntry(
                key: "mory.localData.legacyOwnerID.v1",
                scope: .device,
                note: "Device-level migration marker assigning the old global SwiftData store to one non-guest owner."
            ),
            MoryUserDefaultsScopeEntry(
                key: "mory.localData.lastPreparedOwnerID.v1",
                scope: .device,
                note: "Device-level marker used to clear Spotlight and notifications when active owner changes."
            ),
        ]
    }

    private static func testingBaseDirectoryIfNeeded() -> URL? {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil else {
            return nil
        }
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("mory-xctest-local-data", isDirectory: true)
    }
}
