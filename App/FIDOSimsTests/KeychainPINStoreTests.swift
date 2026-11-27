import FIDOKit
import Foundation
import Security
import Testing

/// Runs in the app-hosted simulator test bundle (Keychain is unreliable from `swift test` on macOS).
/// Failure messages never include PIN values: comparisons are reduced to Bools first.
@Suite("KeychainPINStore", .serialized)
struct KeychainPINStoreTests {
    private let store = KeychainPINStore()

    /// Unique labels per run so real items are never touched; removed in `cleanUp`.
    private let labelA = "test-\(UUID().uuidString)-A"
    private let labelB = "test-\(UUID().uuidString)-B"

    private func cleanUp() {
        try? store.deletePIN(for: labelA)
        try? store.deletePIN(for: labelB)
    }

    private func attributes(for label: String) -> [String: Any]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "fidosims.pin",
            kSecAttrAccount as String: label,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? [String: Any]
    }

    @Test("Save, load, overwrite and delete for two card labels")
    func roundTrip() throws {
        defer { cleanUp() }
        cleanUp()

        let initiallyEmpty = try store.loadPIN(for: labelA) == nil
        #expect(initiallyEmpty)

        try store.savePIN("111111", for: labelA)
        try store.savePIN("222222", for: labelB)
        let aSaved = try store.loadPIN(for: labelA) == "111111"
        let bSaved = try store.loadPIN(for: labelB) == "222222"
        #expect(aSaved)
        #expect(bSaved)

        try store.savePIN("333333", for: labelA)
        let aOverwritten = try store.loadPIN(for: labelA) == "333333"
        let bUntouched = try store.loadPIN(for: labelB) == "222222"
        #expect(aOverwritten)
        #expect(bUntouched)

        try store.deletePIN(for: labelA)
        let aGone = try store.loadPIN(for: labelA) == nil
        let bStill = try store.loadPIN(for: labelB) == "222222"
        #expect(aGone)
        #expect(bStill)

        // Deleting a missing item is not an error.
        try store.deletePIN(for: labelA)
        try store.deletePIN(for: labelB)
        let bGone = try store.loadPIN(for: labelB) == nil
        #expect(bGone)
    }

    @Test("Item uses service fidosims.pin, account = label, WhenUnlockedThisDeviceOnly")
    func itemAttributes() throws {
        defer { cleanUp() }
        try store.savePIN("444444", for: labelA)

        let attrs = try #require(attributes(for: labelA))
        #expect(KeychainPINStore.service == "fidosims.pin")
        #expect(attrs[kSecAttrService as String] as? String == "fidosims.pin")
        #expect(attrs[kSecAttrAccount as String] as? String == labelA)
        #expect(attrs[kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)

        // Overwriting keeps the same protection class.
        try store.savePIN("555555", for: labelA)
        let again = try #require(attributes(for: labelA))
        #expect(again[kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    }
}
