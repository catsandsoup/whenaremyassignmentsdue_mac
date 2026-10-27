import Foundation

final class FixtureProtocol: URLProtocol {
    nonisolated(unsafe) static var responder: ((URLRequest) -> (Int, [String: String], Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, headers, data) = Self.responder(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct APIChecks {
    static func main() async throws {
        if CommandLine.arguments.contains("--live") {
            let data = FileHandle.standardInput.readDataToEndOfFile()
            let token = String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = try await CanvasAPIClient().fetchSnapshot(token: token)
            print("Live API subjects:", result.courses.map(\.course_code).joined(separator: ", "))
            print("Live API:", Deadlines.rows(result).count, "deadline rows;", Deadlines.rows(result).flatMap(\.assignments).count, "links")
            return
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixtureProtocol.self]
        let client = CanvasAPIClient(session: URLSession(configuration: config))
        let now = Deadlines.date("2026-10-15T01:00:00Z")!
        FixtureProtocol.responder = { request in
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-token", "Every page must use the API key")
            precondition(request.value(forHTTPHeaderField: "Cookie") == nil, "No browser session")
            let url = request.url!
            if url.path == "/api/v1/courses", url.query!.contains("page=2") {
                return (200, [:], Data(#"[{"id":2,"name":"BYOD","course_code":"BYOD_TEST_SUPPORT_SITE","workflow_state":"available"},{"id":3,"name":"Old FINC","course_code":"FINC6002","workflow_state":"available","term":{"end_at":"2025-12-31T00:00:00Z"}},{"id":4,"name":"Concluded","course_code":"SIEN6007","workflow_state":"available","concluded":true}]"#.utf8))
            }
            if url.path == "/api/v1/courses" {
                return (200, ["Link":"<https://canvas.sydney.edu.au/api/v1/courses?page=2>; rel=\"next\""], Data(#"[{"id":1,"name":"Finance","course_code":"FINC6001 (ND)","workflow_state":"available","term":{"end_at":"2026-12-31T00:00:00Z"}}]"#.utf8))
            }
            precondition(url.path == "/api/v1/courses/1/assignments", "Only the currently enrolled academic course may be fetched")
            precondition(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "include[]" && $0.value == "submission" }) == true, "Agenda requests must include the current student's submission")
            return (200, [:], Data(#"[{"id":7,"name":"Report","due_at":"2026-10-23T12:59:59Z","html_url":"https://canvas.sydney.edu.au/courses/1/assignments/7","published":true,"submission":{"workflow_state":"submitted","submitted_at":"2026-10-15T00:00:00Z"}}]"#.utf8))
        }
        let snapshot = try await client.fetchSnapshot(token: "fixture-token", now: now)
        precondition(snapshot.courses.first?.assignments.first?.isSubmitted == true, "Decode live submission association")
        precondition(snapshot.courses.map(\.id) == [1], "Filter admin, concluded, and old terms")
        precondition(Deadlines.rows(snapshot, now: now).count == 1)
        for status in [401, 403, 429, 500] {
            FixtureProtocol.responder = { _ in (status, [:], Data("{}".utf8)) }
            do { _ = try await client.fetchSnapshot(token: "fixture-token", now: now); preconditionFailure("Expected HTTP error") }
            catch let error as CanvasAPIError {
                let expected: CanvasAPIError = status == 401 ? .invalidKey : (status == 403 ? .forbidden : .server(status))
                precondition(error == expected, "Only 401 may flag an invalid API key")
            }
        }
        precondition(Deadlines.urgencyLabel(Deadlines.date("2026-10-21T07:00:00Z")!, now: now) == "In 6 days")
        precondition(Deadlines.urgencyLabel(Deadlines.date("2026-10-15T07:00:00Z")!, now: now) == "Today")
        precondition(Deadlines.urgencyLabel(Deadlines.date("2026-10-16T07:00:00Z")!, now: now) == "Tomorrow")
        print("PASS: bearer-only refresh, pagination, student course filtering, 401 vs 403/429/500, and Sydney urgency labels")
    }
}
