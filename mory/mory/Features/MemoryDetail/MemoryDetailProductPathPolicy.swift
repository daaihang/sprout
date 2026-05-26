import Foundation

struct MemoryDetailProductPathPolicy: Hashable, Sendable {
    var environment: AppRuntimeEnvironment

    init(environment: AppRuntimeEnvironment = .current) {
        self.environment = environment
    }

    var exposesAnalysisDebugSurfaces: Bool {
        environment.allowsDebugTools
    }
}
