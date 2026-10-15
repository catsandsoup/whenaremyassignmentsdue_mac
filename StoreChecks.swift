import Foundation

final class StoreFixtureProtocol: URLProtocol {
    nonisolated(unsafe) static var status = 401
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if Self.status == 0 {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1", headerFields: [:])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data((Self.status == 200 ? "invalid JSON" : "{}").utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct StoreChecks {
    static func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        if !value() { print("FAIL:", message); exit(1) }
    }
    @MainActor
    static func main() async throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1]).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/cache-checks-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = directory.appendingPathComponent("Snapshot.json")
        let fixture = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        // An old, already-downloaded timetable must still be visible without updates.
        let archived = String(data: fixture, encoding: .utf8)!.replacingOccurrences(of: "2026-", with: "2000-")
        let saved = Data(archived.utf8)
        try saved.write(to: cache)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StoreFixtureProtocol.self]
        let client = CanvasAPIClient(session: URLSession(configuration: config))
        func load(key: String? = "fixture-token") -> CanvasStore {
            CanvasStore(cacheURL: cache, seedURL: nil, client: client, keyProvider: { key }, automaticallyRefresh: false)
        }
        for status in [401, 403, 429, 500, 200, 0] {
            StoreFixtureProtocol.status = status
            let store = load()
            await store.refresh()?.value
            expect(store.snapshot != nil, "Cached snapshot lost after HTTP \(status)")
            let bytesAfterFailure = try Data(contentsOf: cache)
            expect(bytesAfterFailure == saved, "Cache replaced after failed update \(status)")
            expect(store.displayedRows.count == 9, "Saved timetable disappeared as dates aged without a successful update")
            expect(store.displayedRows.flatMap(\.assignments).count == 16, "Submission links lost after failure")
            expect(store.errorMessage != nil, "Failure must expose a warning")
            expect(!store.syncing, "Update must finish")
            let restarted = load()
            expect(restarted.displayedRows.count == 9, "Restart lost the saved timetable")
        }
        let missingKey = load(key: nil)
        await missingKey.refresh()?.value
        expect(missingKey.displayedRows.count == 9, "A missing API key must not hide saved dates")
        let bytesAfterMissingKey = try Data(contentsOf: cache)
        expect(bytesAfterMissingKey == saved, "A missing key must not modify the cache")
        print("PASS: expired/missing key, denied access, throttling, server/network/JSON failures preserve all 9 saved rows and 16 links across restart and passing dates")
    }
}
