import Foundation

enum MorySharedContainers {
    static let appGroupIdentifier = "group.com.speculolabs.mory"
    static let externalCaptureAttachmentDirectoryName = "ExternalCaptureAttachments"

    static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static var appGroupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
}

struct ExternalCaptureAttachmentFileStore: Sendable {
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
