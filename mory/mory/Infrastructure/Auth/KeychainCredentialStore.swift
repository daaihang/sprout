import Foundation
import Security

actor KeychainCredentialStore {
    private let service = "com.mory.sprout"

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

    func save(identityToken: String, userIdentifier: String) throws {
        let data = try JSONEncoder().encode(["identityToken": identityToken, "userIdentifier": userIdentifier])

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "mory-auth",
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            try update(data: data)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func getIdentityToken() throws -> String? {
        guard let data = try getData() else { return nil }
        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        return decoded["identityToken"]
    }

    func getUserIdentifier() throws -> String? {
        guard let data = try getData() else { return nil }
        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        return decoded["userIdentifier"]
    }

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "mory-auth"
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func update(data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "mory-auth"
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
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
            kSecAttrAccount as String: "mory-auth",
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