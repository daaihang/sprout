import Foundation

enum PrototypeLocalPersistence {
    private static let fileName = "workspace_state.json"

    static func save(_ snapshot: DemoWorkspaceSnapshot) throws {
        let data = try JSONEncoder.pretty.encode(snapshot)
        try data.write(to: fileURL(), options: .atomic)
    }

    static func load() throws -> DemoWorkspaceSnapshot {
        let data = try Data(contentsOf: fileURL())
        return try JSONDecoder.prototype.decode(DemoWorkspaceSnapshot.self, from: data)
    }

    private static func fileURL() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = root.appendingPathComponent("MoryPrototype", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var prototype: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
