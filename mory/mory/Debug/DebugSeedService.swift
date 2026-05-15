import Foundation

@MainActor
enum DebugSeedService {
    static func seed(repository: any MoryMemoryRepositorying) async throws -> DebugMemoryFixtureSnapshot {
        try await repository.seedDebugFixture()
    }
}
