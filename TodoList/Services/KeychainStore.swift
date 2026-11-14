import Foundation
import Security

/// Lưu khoá API trong Keychain của thiết bị.
enum KeychainStore {
    private static let service = "com.example.TodoList"
    private static let account = "anthropic-api-key"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static var apiKey: String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else { return nil }
        return key
    }

    static func setAPIKey(_ key: String) {
        SecItemDelete(baseQuery as CFDictionary)
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var query = baseQuery
        query[kSecValueData as String] = Data(trimmed.utf8)
        SecItemAdd(query as CFDictionary, nil)
    }
}
