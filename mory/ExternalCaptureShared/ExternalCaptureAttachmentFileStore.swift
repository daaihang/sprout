import Foundation

struct ExternalCaptureAttachmentFileStore: Sendable {
    func saveData(_ data: Data, preferredFilename: String) throws -> String {
        guard let directory = Self.attachmentDirectoryURL() else {
            throw ExternalCaptureInboxError.appGroupUnavailable
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sanitized = preferredFilename
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let filename = "\(UUID().uuidString)-\(sanitized)"
        let url = directory.appendingPathComponent(filename, isDirectory: false)
        try data.write(to: url, options: .atomic)
        return filename
    }

    func saveImage(data: Data, preferredFilename: String) throws -> String {
        try saveData(data, preferredFilename: preferredFilename)
    }

    func loadData(storedFileName: String) throws -> Data? {
        guard let directory = Self.attachmentDirectoryURL() else { return nil }
        let url = directory.appendingPathComponent(storedFileName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    static func attachmentDirectoryURL() -> URL? {
        MorySharedContainers.appGroupContainerURL?
            .appendingPathComponent(MorySharedContainers.externalCaptureAttachmentDirectoryName, isDirectory: true)
    }
}
