import Foundation

enum CanvasAPIError: Error, Equatable, LocalizedError {
    case invalidKey, forbidden, server(Int), invalidResponse
    var errorDescription: String? {
        switch self {
        case .invalidKey: "API key expired or invalid."
        case .forbidden: "Canvas denied access. Your API key may still be valid."
        case .server(let status): "Canvas returned HTTP \(status)."
        case .invalidResponse: "Canvas returned an unexpected response."
        }
    }
}

struct EnrolledCourse: Decodable {
    struct Term: Decodable { let end_at: String? }
    let id: Int
    let name: String?
    let course_code: String?
    let workflow_state: String?
    let concluded: Bool?
    let end_at: String?
    let term: Term?

    func isCurrentAcademicCourse(at now: Date) -> Bool {
        guard let course_code,
              course_code.range(of: "^[A-Z]{4}[0-9]{4}\\b", options: .regularExpression) != nil,
              workflow_state == "available", concluded != true else { return false }
        for raw in [end_at, term?.end_at].compactMap({ $0 }) {
            if let end = Deadlines.date(raw), end < now { return false }
        }
        return true
    }
}

struct CanvasAPIClient {
    let session: URLSession
    init(session: URLSession? = nil) {
        if let session { self.session = session }
        else {
            let config = URLSessionConfiguration.ephemeral
            config.httpCookieStorage = nil
            config.httpShouldSetCookies = false
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 120
            self.session = URLSession(configuration: config)
        }
    }

    func pages<T: Decodable>(_ path: String, token: String) async throws -> [T] {
        var next = URL(string: "https://canvas.sydney.edu.au" + path)
        var output: [T] = []
        while let url = next {
            guard url.scheme == "https", url.host == "canvas.sydney.edu.au", url.path.hasPrefix("/api/v1/") else {
                throw CanvasAPIError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw CanvasAPIError.invalidResponse }
            switch http.statusCode {
            case 401: throw CanvasAPIError.invalidKey
            case 403: throw CanvasAPIError.forbidden
            case 200..<300: break
            default: throw CanvasAPIError.server(http.statusCode)
            }
            output += try JSONDecoder().decode([T].self, from: data)
            next = nil
            if let links = http.value(forHTTPHeaderField: "Link") {
                for part in links.components(separatedBy: ",") where part.contains("rel=\"next\"") {
                    if let start = part.firstIndex(of: "<"), let end = part.firstIndex(of: ">"), start < end {
                        next = URL(string: String(part[part.index(after: start)..<end]), relativeTo: url)?.absoluteURL
                    }
                }
            }
        }
        return output
    }

    func fetchSnapshot(token: String, now: Date = Date()) async throws -> CanvasSnapshot {
        let enrolled: [EnrolledCourse] = try await pages("/api/v1/courses?enrollment_type=student&enrollment_state=active&include[]=term&include[]=concluded&per_page=100", token: token)
        var courses: [CanvasCourse] = []
        for course in enrolled where course.isCurrentAcademicCourse(at: now) {
            let assignments: [CanvasAssignment] = try await pages("/api/v1/courses/\(course.id)/assignments?per_page=100", token: token)
            courses.append(CanvasCourse(id: course.id, name: course.name ?? course.course_code!,
                course_code: course.course_code!, assignments: assignments))
        }
        return CanvasSnapshot(checkedAt: ISO8601DateFormatter().string(from: Date()), courses: courses)
    }
}
