import Foundation
import Security

/// Stores each SFTP Source's password in the user's login Keychain, keyed by
/// the `SourceConfig.id`. Password-only auth for v1 (no SSH keys).
enum KeychainCredentialStore {
    private static let service = "com.mochizuki.grandmaresourcemanager.sftp"
    /// Service string used before the app's rename from "Quick File Open
    /// for MA3" — kept only so `migrateLegacyPasswordIfNeeded` can carry
    /// forward passwords saved under the old identifier.
    private static let legacyService = "com.mochizuki.quickfileopen.sftp"

    static func savePassword(_ password: String, for sourceID: UUID) {
        let account = sourceID.uuidString
        let data = Data(password.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func password(for sourceID: UUID) -> String? {
        password(for: sourceID, service: service)
    }

    static func deletePassword(for sourceID: UUID) {
        let account = sourceID.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// One-time carry-forward: if a password exists under the pre-rename
    /// service identifier but not the current one, copies it over (and
    /// removes the old entry) so already-configured SFTP Sources don't
    /// silently lose their saved password after the app rename.
    static func migrateLegacyPasswordIfNeeded(for sourceID: UUID) {
        guard password(for: sourceID, service: service) == nil,
              let legacyPassword = password(for: sourceID, service: legacyService) else {
            return
        }
        savePassword(legacyPassword, for: sourceID)

        let account = sourceID.uuidString
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(legacyQuery as CFDictionary)
    }

    private static func password(for sourceID: UUID, service: String) -> String? {
        let account = sourceID.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
