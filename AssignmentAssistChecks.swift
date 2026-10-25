import Foundation

@main struct AssignmentAssistChecks {
    static func main() async throws {
        var item = FeedbackDesignFixture.items.first!
        item.rubric = [FeedbackCriterion(id: "criterion", description: "Evidence", longDescription: "Use required readings", points: 10, usesRange: false, ratings: [FeedbackRating(id: "rating", description: "Excellent", longDescription: "Every collapsed rating must be included", points: 10)])]
        item.assessments = ["criterion": FeedbackAssessment(points: 2, comments: "PERSONAL FEEDBACK MUST NOT EXPORT", ratingID: nil)]
        var outlined = item
        outlined.sourceAssignment = Data(#"{"description":"<a href='/courses/1/external_tools/9'>Unit of study outline</a>"}"#.utf8)
        guard AssignmentAssistContent.plan(outlined).outlineURL == "https://canvas.sydney.edu.au/courses/1/external_tools/9" else { print("FAIL: use the unit outline link labelled by Canvas, including course tool links"); exit(1) }
        let rubric = AssignmentAssistContent.rubric(item)
        guard rubric.contains("Every collapsed rating must be included"), rubric.contains("Use required readings"), !rubric.contains("PERSONAL FEEDBACK MUST NOT EXPORT"), !rubric.contains("Awarded:") else { print("FAIL: preparation needs complete criteria without personal assessment"); exit(1) }
        precondition(AssignmentAssistContent.cleanURL("https://canvas.sydney.edu.au/files/91/download?verifier=DO-NOT-EXPORT#x")?.absoluteString == "https://canvas.sydney.edu.au/files/91/download")
        precondition(AssignmentAssistContent.cleanURL("javascript:alert(1)") == nil)
        precondition(AssignmentAssistContent.cleanURL("https://user:secret@example.com/a") == nil)
        let longName = AssignmentAssistContent.safeName(String(repeating: "📚", count: 200) + ".pdf")
        precondition(longName.utf8.count <= 180 && longName.hasSuffix(".pdf"))
        precondition(AssignmentAssistContent.cleanURL("https://example.com/outline?year=2026&verifier=secret")?.absoluteString == "https://example.com/outline?year=2026")
        let html = #"<p>Word limit: 2,000 &amp; citations &#8212; required.</p><script>do not execute</script><a href='/courses/1/files/91/download?verifier=DO-NOT-EXPORT'>Brief</a>"#
        precondition(AssignmentAssistContent.text(html).contains("2,000 & citations — required."))
        precondition(!AssignmentAssistContent.text(html).contains("do not execute"))
        precondition(AssignmentAssistContent.references(html).contains { $0.contains("/files/91/") })
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [AssistMockProtocol.self]
        let api = FeedbackAPI(session: URLSession(configuration: config))
        item.courseID = 1; item.assignmentID = 42; item.course = "TEST6001"; item.originalTitle = "Synthetic report"
        item.sourceAssignment = Data(AssistMockProtocol.assignment.utf8)
        let service = AssignmentAssistService(directory: root.appendingPathComponent("cache"), api: api)
        var plan = try await service.prepare(item, token: "test-only")
        precondition(plan.linkedFileIDs.isSuperset(of: [91, 92, 93]))
        precondition(plan.files.map(\.id).sorted() == [91, 92])
        precondition(!AssistMockProtocol.requests.contains { $0.url!.path.hasSuffix("/modules") || $0.url!.path.hasSuffix("/files") }, "Inline material fetching must not crawl unrelated course libraries")
        precondition(plan.outlineURL == "https://www.sydney.edu.au/units/TEST6001")
        precondition(plan.texts.contains { $0.text.contains("Linked page instructions") })
        precondition(plan.warnings.contains { $0.contains("93") })
        precondition(!plan.links.joined().contains("DO-NOT-EXPORT"))
        precondition(AssistMockProtocol.requests.allSatisfy { $0.httpMethod == "GET" && $0.url?.host == "canvas.sydney.edu.au" && !$0.url!.path.contains("/courses/2/") && !$0.url!.path.contains("submissions") && $0.value(forHTTPHeaderField: "Authorization") == "Bearer test-only" })
        let cache = FeedbackFiles(directory: root.appendingPathComponent("cache"))
        for index in plan.files.indices { plan.files[index] = try await cache.commit(Data("Teaching bytes \(plan.files[index].id)".utf8), file: plan.files[index]) }
        let output = root.appendingPathComponent("package.zip")
        let notes = try await service.export(plan, selected: [91, 92], localFiles: [], to: output, token: nil)
        precondition(notes.contains { $0.contains("93") })
        let extracted = root.appendingPathComponent("extracted")
        let unzip = Process(); unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-q", output.path, "-d", extracted.path]
        try unzip.run(); unzip.waitUntilExit(); precondition(unzip.terminationStatus == 0)
        let paths = FileManager.default.enumerator(at: extracted, includingPropertiesForKeys: nil)!.compactMap { $0 as? URL }
        let documents = paths.filter { $0.lastPathComponent.hasPrefix("91-") || $0.lastPathComponent.hasPrefix("92-") }
        precondition(documents.count == 2 && Set(documents.map(\.lastPathComponent)).count == 2)
        for file in documents { let bytes = try String(contentsOf: file, encoding: .utf8); precondition(bytes == (file.lastPathComponent.hasPrefix("91-") ? "Teaching bytes 91" : "Teaching bytes 92")) }
        let text = paths.filter { $0.pathExtension == "txt" }.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined()
        precondition(text.contains("2,000") && text.contains("Every collapsed rating") && text.contains("Linked page instructions"))
        precondition(!text.contains("DO-NOT-EXPORT") && !text.contains("PERSONAL FEEDBACK") && !text.contains("Bearer"))
        AssistMockProtocol.failAll = true
        let offline = try await service.prepare(item, token: nil)
        precondition(offline.files.count == 2 && offline.texts.contains { $0.text.contains("Linked page instructions") })
        let partial = try await service.prepare(item, token: "test-only")
        precondition(partial.files.count == 2 && !partial.warnings.isEmpty)
        let second = root.appendingPathComponent("offline.zip")
        _ = try await service.export(offline, selected: [91], localFiles: [], to: second, token: nil)
        precondition(FileManager.default.fileExists(atPath: second.path))
        print("PASS: complete requirements-only rubric, linked pages/files, course boundaries, clean links, unique safe names, exact ZIP bytes, missing-material notes and offline recovery")
    }
}

final class AssistMockProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var failAll = false
    nonisolated(unsafe) static var requests: [URLRequest] = []
    static let assignment = #"{"id":42,"name":"Synthetic report","published":true,"description":"<p>Word limit: 2,000</p><a href='/courses/1/files/91/download?verifier=DO-NOT-EXPORT'>Brief</a><a href='/courses/1/pages/details'>Details</a><a href='/courses/1/files/93'>Unavailable</a><a href='/courses/2/files/94'>Other course</a>","rubric":[{"id":"criterion","description":"Evidence","long_description":"Use required readings","ratings":[{"id":"rating","description":"Excellent","long_description":"Every collapsed rating must be included","points":10}]}]}"#
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        let path = request.url!.path
        let body: String
        var status = Self.failAll ? 500 : 200
        if path.hasSuffix("/assignments/42") { body = Self.assignment }
        else if path == "/api/v1/courses/1" { body = #"{"id":1,"syllabus_body":"<p>Course syllabus</p><a href='https://www.sydney.edu.au/units/TEST6001'>Unit outline</a>"}"# }
        else if path.hasSuffix("/files/91") { body = #"{"id":91,"hidden_for_user":true,"locked_for_user":false,"display_name":"../Same.txt","url":"https://canvas.sydney.edu.au/files/91/download?verifier=DO-NOT-EXPORT","size":17}"# }
        else if path.hasSuffix("/files/92") { body = #"{"id":92,"display_name":"../Same.txt","url":"https://canvas.sydney.edu.au/files/92/download","size":17}"# }
        else if path.hasSuffix("/files") { body = #"[{"id":91,"hidden_for_user":true,"locked_for_user":false,"display_name":"../Same.txt","url":"https://canvas.sydney.edu.au/files/91/download?verifier=DO-NOT-EXPORT","size":17},{"id":92,"display_name":"../Same.txt","url":"https://canvas.sydney.edu.au/files/92/download","size":17},{"id":93,"display_name":"Locked.txt","url":"https://canvas.sydney.edu.au/files/93/download","locked_for_user":true}]"# }
        else if path.hasSuffix("/pages/details") { body = #"{"published":true,"title":"Details","body":"<p>Linked page instructions</p><a href='/courses/1/files/92'>Template</a>"}"# }
        else { status = 403; body = "{}" }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
