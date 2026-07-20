import Foundation
import Security

final class KeychainStore {
    private let service = "com.ktplife.auth"
    private let account = "auth-tokens"
    private let accessibleAttribute = kSecAttrAccessibleAfterFirstUnlock as String

    func loadTokens() throws -> AuthTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess,
              let data = result as? Data else {
            throw KeychainError.unableToRead(status)
        }

        return try JSONDecoder().decode(AuthTokens.self, from: data)
    }

    func saveTokens(_ tokens: AuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: accessibleAttribute,
            kSecAttrSynchronizable as String: false
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibleAttribute,
            kSecAttrSynchronizable as String: false
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unableToSave(addStatus)
            }
            return
        }

        guard status == errSecSuccess else {
            throw KeychainError.unableToSave(status)
        }
    }

    func deleteTokens() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status)
        }
    }
}

enum KeychainError: LocalizedError {
    case unableToRead(OSStatus)
    case unableToSave(OSStatus)
    case unableToDelete(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unableToRead(let status):
            return "Keychain read failed with status \(status)"
        case .unableToSave(let status):
            return "Keychain save failed with status \(status)"
        case .unableToDelete(let status):
            return "Keychain delete failed with status \(status)"
        }
    }
}
