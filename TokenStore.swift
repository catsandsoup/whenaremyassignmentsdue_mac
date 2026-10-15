import Foundation
import Security

enum TokenStore {
    private static let service = "au.monty.assignmentdates.canvas-api"
    private static let account = "canvas.sydney.edu.au"
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    static func read() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &value) == errSecSuccess,
              let data = value as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TokenError.empty }
        let attributes = [kSecValueData as String: Data(trimmed.utf8)]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw TokenError.keychain(status) }
    }
    enum TokenError: LocalizedError {
        case empty, keychain(OSStatus)
        var errorDescription: String? {
            switch self {
            case .empty: "Enter a Canvas API key."
            case .keychain(let status): "Could not save API key (Keychain \(status))."
            }
        }
    }
}
