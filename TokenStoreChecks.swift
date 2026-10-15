import Foundation
@main struct TokenStoreChecks {
    static func main() {
        precondition(TokenStore.helperMayRead(promptFlags: 0))
        precondition(!TokenStore.helperMayRead(promptFlags: 1), "Password-required ACL must never launch an interactive helper")
        precondition(!TokenStore.helperMayRead(promptFlags: 2), "Unknown prompt flags fail closed")
        let cache = CredentialReadCache()
        var reads = 0
        for _ in 0..<100 { precondition(cache.read { reads += 1; return "synthetic" } == "synthetic") }
        precondition(reads == 1)
        cache.replace("replacement")
        precondition(cache.read { preconditionFailure("Unexpected credential retry") } == "replacement")
        let denied = CredentialReadCache()
        for _ in 0..<100 { precondition(denied.read { reads += 1; return nil } == nil) }
        precondition(reads == 2, "Denied credential access must not be retried by another feature or timer")
        print("PASS: one shared credential read, no retry after denial, explicit replacement updates in-memory key")
    }
}
