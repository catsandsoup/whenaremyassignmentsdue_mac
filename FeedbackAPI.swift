import Foundation

struct FeedbackCourseResult: Sendable {
    var courseID: Int
    var items: [FeedbackItem]
    var warning: String?
}
struct FeedbackFetchResult: Sendable {
    var courses: [FeedbackCourseResult]
    var userID: Int
    var checkedAt: String
}
enum FeedbackError: Error, LocalizedError {
    case invalidData, unavailable(String)
    var errorDescription: String? {
        switch self {
        case .invalidData: "Canvas returned incomplete or inconsistent feedback. Your saved information is unchanged."
        case .unavailable(let message): message
        }
    }
}
final class FeedbackRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let allowFiles: Bool
    init(allowFiles: Bool = false) { self.allowFiles = allowFiles }
    static func request(_ request: URLRequest, allowFiles: Bool) -> URLRequest? {
        guard let url = request.url, url.scheme == "https" else { return nil }
        var result = request
        if url.host != "canvas.sydney.edu.au" {
            guard allowFiles else { return nil }
            result.setValue(nil, forHTTPHeaderField: "Authorization")
        }
        return result
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(Self.request(request, allowFiles: allowFiles))
    }
}
struct FeedbackAPI: Sendable {
    let session: URLSession
    init(session: URLSession? = nil) {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 120
        self.session = session ?? URLSession(configuration: config, delegate: FeedbackRedirectPolicy(), delegateQueue: nil)
    }
    func get(_ url: URL, token: String) async throws -> (Data, HTTPURLResponse) {
        guard url.scheme == "https", url.host == "canvas.sydney.edu.au", url.path.hasPrefix("/api/v1/"), !(url.query ?? "").contains("read_status") else { throw FeedbackError.invalidData }
        var request = URLRequest(url: url)
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FeedbackError.invalidData }
        switch http.statusCode {
        case 401: throw CanvasAPIError.invalidKey
        case 403: throw CanvasAPIError.forbidden
        case 200..<300: break
        default: throw CanvasAPIError.server(http.statusCode)
        }
        return (data, http)
    }
    func pages(_ path: String, token: String) async throws -> [Data] {
        var next = URL(string: "https://canvas.sydney.edu.au" + path)
        var visited = Set<URL>(), result: [Data] = []
        while let url = next {
            guard visited.insert(url).inserted else { throw FeedbackError.invalidData }
            let (data, response) = try await get(url, token: token)
            guard let values = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw FeedbackError.invalidData }
            result += try values.map { try JSONSerialization.data(withJSONObject: $0) }
            next = nil
            for part in (response.value(forHTTPHeaderField: "Link") ?? "").components(separatedBy: ",") where part.contains("rel=\"next\"") {
                if let start = part.firstIndex(of: "<"), let end = part.firstIndex(of: ">"), start < end {
                    next = URL(string: String(part[part.index(after: start)..<end]), relativeTo: url)?.absoluteURL
                }
            }
        }
        return result
    }
    func fetch(token: String) async throws -> FeedbackFetchResult {
        let enrolled = try await pages("/api/v1/courses?enrollment_type=student&enrollment_state=active&include[]=term&include[]=concluded&per_page=100", token: token)
        let checkedAt = ISO8601DateFormatter().string(from: Date())
        var current: [(Int, String, Int)] = []
        for raw in enrolled {
            let c = try JSONDecoder().decode(EnrolledCourse.self, from: raw)
            guard c.isCurrentAcademicCourse(at: Date()) else { continue }
            let json = try Self.object(raw)
            let enrollment = (json["enrollments"] as? [[String: Any]])?.first { $0["type"] as? String == "student" }
            guard let user = enrollment?["user_id"] as? Int, let code = c.course_code else { throw FeedbackError.invalidData }
            current.append((c.id, String(code.prefix(8)), user))
        }
        guard let userID = current.first?.2, current.allSatisfy({ $0.2 == userID }) else { throw FeedbackError.unavailable("No active academic student subjects were returned. Your saved feedback remains available.") }
        var courses: [FeedbackCourseResult] = []
        // Four course streams are deliberately serial; avoids burst traffic and preserves per-course success.
        for (courseID, code, user) in current {
            try Task.checkCancellation()
            do {
                let assignments = try await pages("/api/v1/courses/\(courseID)/assignments?include[]=submission&per_page=100", token: token)
                var incomplete = false
                var submissions: [Data] = []
                do { submissions = try await pages("/api/v1/courses/\(courseID)/students/submissions?student_ids[]=self&include[]=submission_comments&include[]=rubric_assessment&include[]=submission_history&per_page=100", token: token) }
                catch CanvasAPIError.invalidKey { throw CanvasAPIError.invalidKey }
                catch { incomplete = true }
                var byAssignment: [Int: Data] = [:]
                for submission in submissions {
                    let object = try Self.object(submission)
                    guard let id = object["assignment_id"] as? Int, object["user_id"] as? Int == user else { throw FeedbackError.invalidData }
                    byAssignment[id] = submission
                }
                var values: [FeedbackItem] = []
                for assignment in assignments {
                    let object = try Self.object(assignment)
                    guard object["published"] as? Bool != false, let id = object["id"] as? Int else { continue }
                    if let submission = byAssignment[id] {
                        var complete = submission
                        var detailComplete = true
                        let bulk = try Self.object(submission)
                        if !(object["rubric"] as? [Any] ?? []).isEmpty || !(bulk["submission_comments"] as? [Any] ?? []).isEmpty {
                            do {
                                let path = "https://canvas.sydney.edu.au/api/v1/courses/\(courseID)/assignments/\(id)/submissions/self?include[]=submission_comments&include[]=rubric_assessment&include[]=full_rubric_assessment&include[]=submission_history"
                                let detail = try await get(URL(string: path)!, token: token).0
                                _ = try Self.item(assignment: assignment, submission: detail, courseID: courseID, course: code, userID: user, checkedAt: checkedAt)
                                complete = detail
                            } catch CanvasAPIError.invalidKey { throw CanvasAPIError.invalidKey }
                            catch { incomplete = true; detailComplete = false }
                        }
                        var value = try Self.item(assignment: assignment, submission: complete, courseID: courseID, course: code, userID: user, checkedAt: checkedAt)
                        value.submissionComplete = detailComplete
                        values.append(value)
                    } else if let embedded = object["submission"] as? [String: Any], embedded["user_id"] as? Int == user {
                        // Preserve assignment criteria even if a submission resource was omitted. Store merges old feedback separately.
                        var value = try Self.item(assignment: assignment, submission: JSONSerialization.data(withJSONObject: embedded), courseID: courseID, course: code, userID: user, checkedAt: checkedAt)
                        value.submissionComplete = false
                        values.append(value); incomplete = true
                    } else {
                        let stub: [String: Any] = ["assignment_id": id, "user_id": user, "workflow_state": "unavailable"]
                        var value = try Self.item(assignment: assignment, submission: JSONSerialization.data(withJSONObject: stub), courseID: courseID, course: code, userID: user, checkedAt: checkedAt)
                        value.submissionComplete = false
                        values.append(value); incomplete = true
                    }
                }
                courses.append(FeedbackCourseResult(courseID: courseID, items: values, warning: incomplete ? "Some submission details were unavailable. Saved feedback has been retained." : nil))
            } catch CanvasAPIError.invalidKey { throw CanvasAPIError.invalidKey }
            catch {
                courses.append(FeedbackCourseResult(courseID: courseID, items: [], warning: "Could not update " + code + ". Saved feedback remains available."))
            }
        }
        return FeedbackFetchResult(courses: courses, userID: userID, checkedAt: checkedAt)
    }
    static func object(_ data: Data) throws -> [String: Any] {
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw FeedbackError.invalidData }
        return value
    }
    static func item(assignment data: Data, submission submissionData: Data, courseID: Int, course: String, userID: Int, checkedAt: String) throws -> FeedbackItem {
        let a = try object(data), s = try object(submissionData)
        guard let id = a["id"] as? Int, let title = a["name"] as? String,
              s["assignment_id"] as? Int == id, s["user_id"] as? Int == userID else { throw FeedbackError.invalidData }
        let original = CanvasAssignment(id: id, name: title, due_at: nil, html_url: nil, published: true)
        var display = original.displayName
        if display.lowercased().hasPrefix("individual assignment:") { display = "Individual assignment" }
        var result = FeedbackItem(id: "canvas.sydney.edu.au:\(userID):\(courseID):\(id)", assignmentID: id, courseID: courseID, userID: userID, course: course, title: display, originalTitle: title, pointsPossible: a["points_possible"] as? Double, score: s["score"] as? Double, grade: s["grade"] as? String, postedAt: s["posted_at"] as? String, submittedAt: s["submitted_at"] as? String, attempt: s["attempt"] as? Int, workflowState: s["workflow_state"] as? String ?? "unsubmitted", checkedAt: checkedAt)
        result.late = s["late"] as? Bool ?? false; result.missing = s["missing"] as? Bool ?? false
        result.gradeMatchesCurrent = s["grade_matches_current_submission"] as? Bool ?? true
        result.comments = (s["submission_comments"] as? [[String: Any]] ?? []).compactMap { c in
            guard let id = c["id"] as? Int else { return nil }
            return FeedbackComment(id: id, author: c["author_name"] as? String ?? "Lecturer", text: c["comment"] as? String ?? "", createdAt: c["created_at"] as? String, attachments: attachments(c["attachments"]))
        }.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
        result.submissionFiles = attachments(s["attachments"])
        result.rubric = (a["rubric"] as? [[String: Any]] ?? []).compactMap { c in
            guard let id = stringID(c["id"]), let description = c["description"] as? String else { return nil }
            return FeedbackCriterion(id: id, description: description, longDescription: c["long_description"] as? String ?? "", points: c["points"] as? Double, usesRange: c["criterion_use_range"] as? Bool ?? false, ratings: (c["ratings"] as? [[String: Any]] ?? []).compactMap { r in
                guard let id = stringID(r["id"]) else { return nil }
                return FeedbackRating(id: id, description: r["description"] as? String ?? "", longDescription: r["long_description"] as? String ?? "", points: r["points"] as? Double)
            })
        }
        guard Set(result.rubric.map(\.id)).count == result.rubric.count,
              result.rubric.allSatisfy({ Set($0.ratings.map(\.id)).count == $0.ratings.count }) else { throw FeedbackError.invalidData }
        let settings = a["rubric_settings"] as? [String: Any] ?? [:]
        result.rubricTitle = settings["title"] as? String ?? "Marking criteria"
        result.hideRubricPoints = settings["hide_points"] as? Bool ?? false
        result.hideRubricTotal = settings["hide_score_total"] as? Bool ?? false
        var assessment = s["rubric_assessment"] as? [String: Any] ?? [:]
        if let full = s["full_rubric_assessment"] as? [String: Any] {
            if let detail = full["data"] as? [String: Any] { assessment = detail }
            result.assessmentType = full["assessment_type"] as? String
            result.assessmentAttempt = full["artifact_attempt"] as? Int
        }
        for (key, raw) in assessment {
            guard let value = raw as? [String: Any] else { continue }
            result.assessments[key] = FeedbackAssessment(points: value["points"] as? Double, comments: value["comments"] as? String, ratingID: stringID(value["rating_id"]))
        }
        result.history = (s["submission_history"] as? [[String: Any]] ?? []).compactMap { h in
            guard let attempt = h["attempt"] as? Int else { return nil }
            return FeedbackAttempt(attempt: attempt, submittedAt: h["submitted_at"] as? String, state: h["workflow_state"] as? String ?? "", files: attachments(h["attachments"]))
        }.sorted { $0.attempt < $1.attempt }
        // Raw API payloads are retained locally for lossless future decoding, never executed or uploaded.
        result.sourceAssignment = data; result.sourceSubmission = submissionData
        return result
    }
    static func stringID(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        if let number = value as? Int { return String(number) }
        return nil
    }
    static func attachments(_ value: Any?) -> [FeedbackAttachment] {
        (value as? [[String: Any]] ?? []).compactMap { f in
            guard let id = f["id"] as? Int, let name = f["display_name"] as? String, let url = f["url"] as? String else { return nil }
            return FeedbackAttachment(id: id, name: name, url: url, contentType: f["content-type"] as? String ?? f["content_type"] as? String ?? "application/octet-stream", size: f["size"] as? Int ?? 0, updatedAt: f["updated_at"] as? String)
        }
    }
}
