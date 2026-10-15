import Foundation
@main struct FeedbackAPIChecks {
    static func main() async throws {
        let assignment = Data(#"{"id":42,"name":"Written Report","points_possible":30,"rubric_settings":{"hide_points":true},"rubric":[{"id":"one","description":"Evidence","long_description":"Full description","points":2.5,"criterion_use_range":true,"ratings":[{"id":"blank","description":"Excellent","long_description":"Long rating","points":2.5}]}]}"#.utf8)
        let submission = Data(#"{"assignment_id":42,"user_id":7,"workflow_state":"graded","score":0,"grade":"0","posted_at":"2026-10-15T01:00:00Z","attempt":2,"rubric_assessment":{"one":{"points":0,"comments":"Improve evidence"}},"submission_comments":[{"id":3,"author_name":"Lecturer","comment":"Feedback","attachments":[{"id":9,"display_name":"Feedback.pdf","url":"https://canvas.sydney.edu.au/files/9/download","content-type":"application/pdf","size":100}]}]}"#.utf8)
        let value = try FeedbackAPI.item(assignment: assignment, submission: submission, courseID: 1, course: "TEST6001", userID: 7, checkedAt: "2026-10-15T01:00:00Z")
        precondition(value.markLabel == "0/30")
        precondition(value.hideRubricPoints && value.rubric[0].usesRange)
        precondition(value.rubric[0].ratings[0].longDescription == "Long rating")
        precondition(value.assessments["one"]?.points == 0)
        precondition(value.attachments[0].id == 9)
        let wrongUser = submission.replacingString("\"user_id\":7", "\"user_id\":8")
        do { _ = try FeedbackAPI.item(assignment: assignment, submission: wrongUser, courseID: 1, course: "TEST6001", userID: 7, checkedAt: "now"); preconditionFailure("Wrong user accepted") } catch {}
        var request = URLRequest(url: URL(string: "https://other.example/file")!)
        request.setValue("Bearer fake", forHTTPHeaderField: "Authorization")
        precondition(FeedbackRedirectPolicy.request(request, allowFiles: true)?.value(forHTTPHeaderField: "Authorization") == nil)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [FeedbackMockProtocol.self]
        config.httpCookieStorage = nil; config.httpShouldSetCookies = false
        let api = FeedbackAPI(session: URLSession(configuration: config))
        FeedbackMockProtocol.status = 200
        let fetched = try await api.fetch(token: "test-only")
        precondition(fetched.courses.count == 1 && fetched.courses[0].items.count == 1)
        precondition(FeedbackMockProtocol.requests.allSatisfy { $0.httpMethod == "GET" && !($0.url?.absoluteString.contains("read_status") ?? true) && $0.value(forHTTPHeaderField: "Cookie") == nil })
        FeedbackMockProtocol.status = 403; FeedbackMockProtocol.failurePath = "/submissions/self"
        let detailFailure = try await api.fetch(token: "test-only")
        if detailFailure.courses[0].items.first?.submissionComplete != false {
            print("FAIL: failed detail must flag the submission incomplete to preserve saved assessment"); exit(1)
        }
        FeedbackMockProtocol.status = 200; FeedbackMockProtocol.malformedDetail = true
        let malformed = try await api.fetch(token: "test-only")
        precondition(malformed.courses[0].items.first?.submissionComplete == false && malformed.courses[0].items.first?.rubric.count == 1)
        FeedbackMockProtocol.malformedDetail = false
        FeedbackMockProtocol.status = 500; FeedbackMockProtocol.failurePath = "/students/submissions"
        let submissionFailure = try await api.fetch(token: "test-only")
        if submissionFailure.courses[0].items.first?.rubric.count != 1 {
            print("FAIL: successfully fetched rubric must survive a submissions endpoint failure"); exit(1)
        }
        FeedbackMockProtocol.failurePath = nil
        for status in [403, 429, 500] {
            FeedbackMockProtocol.status = status
            let partial = try await api.fetch(token: "test-only")
            precondition(partial.courses[0].warning != nil && partial.courses[0].items.isEmpty)
        }
        FeedbackMockProtocol.status = 401
        do { _ = try await api.fetch(token: "test-only"); preconditionFailure("401 not rejected") } catch CanvasAPIError.invalidKey {}
        FeedbackMockProtocol.status = 200; FeedbackMockProtocol.externalPage = true
        do { _ = try await api.pages("/api/v1/courses?per_page=1", token: "test-only"); preconditionFailure("External pagination accepted") } catch {}
        print("PASS: GET-only bearer refresh, no cookies/read-status, own-user scope, partial 403/429/500 failures, 401 invalid-key and rejected external pagination")
        print("PASS: Canvas mapping preserves released zero, range/fraction rubric descriptions, hidden points, comments and attachment identity; rejects wrong user")
    }
}
extension Data {
    func replacingString(_ a: String, _ b: String) -> Data { Data(String(decoding: self, as: UTF8.self).replacingOccurrences(of: a, with: b).utf8) }
}

final class FeedbackMockProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var externalPage = false
    nonisolated(unsafe) static var malformedDetail = false
    nonisolated(unsafe) static var failurePath: String?
    nonisolated(unsafe) static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        let path = request.url!.path
        let courses = path == "/api/v1/courses"
        let status = courses ? 200 : (Self.failurePath.map { path.hasSuffix($0) ? Self.status : 200 } ?? Self.status)
        let body: String
        if courses { body = #"[{"id":1,"name":"Testing","course_code":"TEST6001","workflow_state":"available","enrollments":[{"type":"student","user_id":7}]}]"# }
        else if path.hasSuffix("/assignments") { body = #"[{"id":42,"name":"Synthetic assignment","published":true,"points_possible":5,"rubric":[{"id":"one","description":"Evidence","points":2.5,"ratings":[]}]}]"# }
        else if path.hasSuffix("/submissions/self") { body = Self.malformedDetail ? "{}" : #"{"assignment_id":42,"user_id":7,"workflow_state":"unsubmitted"}"# }
        else { body = #"[{"assignment_id":42,"user_id":7,"workflow_state":"unsubmitted"}]"# }
        let headers = Self.externalPage ? ["Link":"<https://other.example/api/v1/courses?page=2>; rel=\"next\""] : [:]
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
