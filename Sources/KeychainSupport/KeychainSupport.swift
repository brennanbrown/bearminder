import Foundation

public enum KeychainError: Error {
    case notFound
    case unexpectedData
    case unhandled(OSStatus)
}

// MARK: - Combined tokens (single item) to minimize Keychain prompts
public struct CombinedTokens: Codable { public let beeminder: String; public let bear: String }

public extension KeychainStore {
    private var combinedService: String { "bearminder" }
    private var combinedAccount: String { "tokens" }

    func setCombinedTokens(beeminder: String, bear: String) throws {
        let payload = CombinedTokens(beeminder: beeminder, bear: bear)
        let data = try JSONEncoder().encode(payload)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: combinedAccount,
            kSecAttrService as String: combinedService,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    func getCombinedTokens() throws -> CombinedTokens {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: combinedAccount,
            kSecAttrService as String: combinedService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == errSecSuccess, let data = item as? Data else { throw KeychainError.unexpectedData }
        guard let decoded = try? JSONDecoder().decode(CombinedTokens.self, from: data) else { throw KeychainError.unexpectedData }
        return decoded
    }
}

public protocol SecureStoreType {
    func setPassword(_ password: String, account: String, service: String) throws
    func getPassword(account: String, service: String) throws -> String
    func deletePassword(account: String, service: String) throws
}

public final class KeychainStore: SecureStoreType {
    public init() {}

    public func setPassword(_ password: String, account: String, service: String) throws {
        let data = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    public func getPassword(account: String, service: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { throw KeychainError.notFound }
        guard status == errSecSuccess, let data = item as? Data, let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return password
    }

    public func deletePassword(account: String, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unhandled(status) }
    }
}
