import Foundation
import Security

/// Keychain generic passwords: service `fidosims.pin`, account = card label,
/// accessible `WhenUnlockedThisDeviceOnly` (never synced, never in backups to other devices).
public struct KeychainPINStore: PINStore {
    public static let service = "fidosims.pin"

    public init() {}

    public func savePIN(_ pin: String, for cardLabel: String) throws {
        let query = baseQuery(cardLabel)
        let attributes: [String: Any] = [
            kSecValueData as String: Data(pin.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let added = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainPINStoreError(status: added) }
        } else if status != errSecSuccess {
            throw KeychainPINStoreError(status: status)
        }
    }

    public func loadPIN(for cardLabel: String) throws -> String? {
        var query = baseQuery(cardLabel)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainPINStoreError(status: status) }
        return String(decoding: data, as: UTF8.self)
    }

    public func deletePIN(for cardLabel: String) throws {
        let status = SecItemDelete(baseQuery(cardLabel) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainPINStoreError(status: status) }
    }

    private func baseQuery(_ cardLabel: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: cardLabel,
        ]
    }
}
