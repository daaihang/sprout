import Foundation
import Security

// MARK: - Stored Credential

struct AuthCredential: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date?
    let userID: String
    let identityToken: String?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        // Treat as expired 5 minutes early to avoid edge-case failures
        return Date() >= expiresAt.addingTimeInterval(-300)
    }

    var isGuest: Bool { userID == "guest" }

    static let guest = AuthCredential(
        accessToken: "guest",
        refreshToken: "guest",
        expiresAt: nil,
        userID: "guest",
        identityToken: nil
    )
}

// MARK: - Keychain Store

actor KeychainCredentialStore {
    private let service: String
    private let account: String
    private let usesInMemoryStore: Bool
    private var inMemoryCredential: AuthCredential?

    init(
        service: String = "com.mory.sprout",
        account: String = "mory-auth",
        inMemory: Bool = false
    ) {
        self.service = service
        self.account = account
        self.usesInMemoryStore = inMemory || service == "__memory__"
    }

    enum KeychainError: Error, LocalizedError {
        case duplicateItem
        case itemNotFound
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .duplicateItem:
                return "Credential already exists in keychain."
            case .itemNotFound:
                return "Credential not found in keychain."
            case let .unexpectedStatus(status):
                return "Keychain error: \(status)"
            }
        }
    }

    // MARK: - Full credential (v4)

    func saveCredential(_ credential: AuthCredential) throws {
        if usesInMemoryStore {
            inMemoryCredential = credential
            return
        }

        let data = try JSONEncoder().encode(credential)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            try update(data: data)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func loadCredential() -> AuthCredential? {
        if usesInMemoryStore {
            return inMemoryCredential
        }

        guard let data = try? getData() else { return nil }
        // Try v4 format first (AuthCredential)
        if let credential = try? JSONDecoder().decode(AuthCredential.self, from: data) {
            return credential
        }
        // Fallback: v3 format (dictionary with identityToken + userIdentifier)
        if let dict = try? JSONDecoder().decode([String: String].self, from: data),
           let identityToken = dict["identityToken"],
           let userId = dict["userIdentifier"] {
            return AuthCredential(
                accessToken: "",
                refreshToken: "",
                expiresAt: nil,
                userID: userId,
                identityToken: identityToken
            )
        }
        return nil
    }

    // MARK: - Legacy compatibility (v3 API)

    func save(identityToken: String, userIdentifier: String) throws {
        let credential = AuthCredential(
            accessToken: "",
            refreshToken: "",
            expiresAt: nil,
            userID: userIdentifier,
            identityToken: identityToken
        )
        try saveCredential(credential)
    }

    func getIdentityToken() throws -> String? {
        loadCredential()?.identityToken
    }

    func getUserIdentifier() throws -> String? {
        loadCredential()?.userID
    }

    // MARK: - Delete

    func delete() throws {
        if usesInMemoryStore {
            inMemoryCredential = nil
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Private

    private func update(data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func getData() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        return result as? Data
    }
}
