import Foundation

// MARK: - Completion Handler Store

final class BackgroundURLSessionCompletionStore {
    static let shared = BackgroundURLSessionCompletionStore()
    private init() {}
    var handler: (() -> Void)?
}

// MARK: - URLSession Delegate

final class BackgroundURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            BackgroundURLSessionCompletionStore.shared.handler?()
            BackgroundURLSessionCompletionStore.shared.handler = nil
        }
    }
}

// MARK: - Shared background session

extension MoryAPIClient {
    static let backgroundURLSessionDelegate = BackgroundURLSessionDelegate()

    static let backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: backgroundSessionID)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(
            configuration: config,
            delegate: backgroundURLSessionDelegate,
            delegateQueue: nil
        )
    }()
}
