import Foundation
import AppKit
@main struct FeedbackStoreChecks {
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("feedback-store-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try FeedbackRepository.open(directory: root)
        let values = FeedbackDesignFixture.items
        _ = try await repository.merge(FeedbackFetchResult(courses: [FeedbackCourseResult(courseID: 1, items: values, warning: nil)], userID: 1, checkedAt: values[0].checkedAt))
        let missing = FeedbackStore(directory: root, keyProvider: { nil }, automaticallyRefresh: false)
        await missing.waitForLoad()
        precondition(missing.items.count == values.count)
        missing.refresh()
        precondition(missing.items.count == values.count && missing.errorMessage?.contains("no API key") == true)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [FeedbackFailureProtocol.self]
        let expired = FeedbackStore(directory: root, api: FeedbackAPI(session: URLSession(configuration: config)), keyProvider: { "synthetic-key" }, automaticallyRefresh: false)
        await expired.waitForLoad()
        for status in [401, 403, 429, 500] {
            FeedbackFailureProtocol.status = status
            await expired.refresh()?.value
            precondition(expired.items.count == values.count && expired.errorMessage != nil)
            precondition(expired.checkedAt == values[0].checkedAt)
            let reopened = FeedbackStore(directory: root, keyProvider: { nil }, automaticallyRefresh: false)
            await reopened.waitForLoad()
            precondition(reopened.items.count == values.count && reopened.items.flatMap(\.rubric).count == values.flatMap(\.rubric).count)
        }
        print("PASS: feedback coordinator preserves marks, comments, rubrics and timestamp across missing/expired key, 403/429/500 and restart")
    }
}
final class FeedbackFailureProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 401
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
