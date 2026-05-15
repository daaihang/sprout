import Foundation

@MainActor
enum DebugSeedService {
    static func seed(repository: any MoryMemoryRepositorying) throws -> DebugMemoryFixtureSnapshot {
        try repository.seedDebugFixture()
    }
}
