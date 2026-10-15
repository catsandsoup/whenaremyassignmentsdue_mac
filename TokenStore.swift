import Foundation
import Security
import LocalAuthentication

// Shared by deadlines, feedback and downloads. Cache a failed read as well: timers must never retry an OS consent prompt.
final class CredentialReadCache {
    private let lock = NSLock()
    private var loaded = false
    private var token: String?
    func read(_ load: () -> String?) -> String? {
        lock.lock(); defer { lock.unlock() }
        if !loaded { token = load(); loaded = true }
        return token
    }
    func replace(_ value: String) {
        lock.lock(); defer { lock.unlock() }
        token = value; loaded = true
    }
}

enum TokenStore {
    private static let service = "au.monty.assignmentdates.canvas-api"
    private static let account = "canvas.sydney.edu.au"
    private static let cache = CredentialReadCache()
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    private static var silentQuery: [String: Any] {
        // This app uses the existing macOS file-based keychain. Disable its legacy UI as well as LA UI.
        SecKeychainSetUserInteractionAllowed(false)
        let context = LAContext(); context.interactionNotAllowed = true
        return query.merging([kSecUseAuthenticationContext as String: context]) { _, new in new }
    }
    static func read() -> String? {
        cache.read {
            // The Apple-signed helper has a stable identity across app rebuilds. Only use it when the
            // existing item's decrypt ACL already trusts it and its keychain is unlocked. Never widen an ACL here.
            if trustedHelperAvailable() { return helperRead() }
            var request = silentQuery
            request[kSecReturnData as String] = true
            request[kSecMatchLimit as String] = kSecMatchLimitOne
            var value: CFTypeRef?
            guard SecItemCopyMatching(request as CFDictionary, &value) == errSecSuccess,
                  let data = value as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
    }
    private static func trustedHelperAvailable() -> Bool {
        var request = silentQuery; request[kSecReturnRef as String] = true
        var value: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &value) == errSecSuccess, let value else { return false }
        let item = value as! SecKeychainItem
        var keychain: SecKeychain?
        guard SecKeychainItemCopyKeychain(item, &keychain) == errSecSuccess, let keychain else { return false }
        var status: SecKeychainStatus = 0
        guard SecKeychainGetStatus(keychain, &status) == errSecSuccess, status & UInt32(kSecUnlockStateStatus) != 0 else { return false }
        var access: SecAccess?
        guard SecKeychainItemCopyAccess(item, &access) == errSecSuccess, let access else { return false }
        var list: CFArray?
        guard SecAccessCopyACLList(access, &list) == errSecSuccess, let acls = list as? [SecACL] else { return false }
        return acls.contains { acl in
            let authorizations = SecACLCopyAuthorizations(acl) as? [String] ?? []
            guard authorizations.contains("ACLAuthorizationDecrypt") else { return false }
            var applications: CFArray?; var description: CFString?; var prompt = SecKeychainPromptSelector()
            guard SecACLCopyContents(acl, &applications, &description, &prompt) == errSecSuccess,
                  helperMayRead(promptFlags: prompt.rawValue),
                  let applications = applications as? [SecTrustedApplication] else { return false }
            return applications.contains { application in
                var data: CFData?
                guard SecTrustedApplicationCopyData(application, &data) == errSecSuccess, let data else { return false }
                return String(decoding: data as Data, as: UTF8.self).trimmingCharacters(in: .controlCharacters) == "/usr/bin/security"
            }
        }
    }
    static func helperMayRead(promptFlags: UInt16) -> Bool { promptFlags == 0 }
    private static func helperRead() -> String? {
        let process = Process(); let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-a", account, "-w"]
        process.standardOutput = output; process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let token = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return token.isEmpty ? nil : token
        } catch { return nil }
    }
    static func save(_ token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TokenError.empty }
        let attributes = [kSecValueData as String: Data(trimmed.utf8)]
        var status = SecItemUpdate(silentQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var creation = query.merging(attributes) { _, new in new }
            var app: SecTrustedApplication?, helper: SecTrustedApplication?, access: SecAccess?
            if SecTrustedApplicationCreateFromPath(nil, &app) == errSecSuccess,
               SecTrustedApplicationCreateFromPath("/usr/bin/security", &helper) == errSecSuccess,
               let app, let helper,
               SecAccessCreate("Assignment Dates Canvas API key" as CFString, [app, helper] as CFArray, &access) == errSecSuccess, let access {
                creation[kSecAttrAccess as String] = access
            }
            status = SecItemAdd(creation as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw TokenError.keychain(status) }
        cache.replace(trimmed)
    }
    enum TokenError: LocalizedError {
        case empty, keychain(OSStatus)
        var errorDescription: String? {
            switch self {
            case .empty: "Enter a Canvas API key."
            case .keychain: "The key could not be saved silently. Your existing key and saved information are unchanged."
            }
        }
    }
}
