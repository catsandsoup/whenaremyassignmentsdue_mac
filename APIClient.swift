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
            let (data, http) = try await CanvasNetworking.data(for: request,session:session)
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

// One account-wide queue keeps concurrent page/file work below Canvas's parallel-request penalty.
actor CanvasRequestGate {
    static let shared = CanvasRequestGate(limit:4)
    private let maximum: Int
    private var active = 0
    private var pending: [(UUID,CheckedContinuation<Void,Error>)] = []
    private var pauseUntil = Date.distantPast
    private var conservativeUntil = Date.distantPast
    private var wake: Task<Void,Never>?
    init(limit: Int) { maximum = max(1,limit) }
    func acquire() async throws {
        try Task.checkCancellation()
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation:CheckedContinuation<Void,Error>) in
                if Task.isCancelled { continuation.resume(throwing:CancellationError()); return }
                pending.append((id,continuation)); drain()
            }
        } onCancel: { Task { await self.cancel(id) } }
    }
    private func cancel(_ id: UUID) {
        guard let i = pending.firstIndex(where: { $0.0 == id }) else { return }
        pending.remove(at:i).1.resume(throwing:CancellationError())
    }
    func release() { active = max(0,active-1); drain() }
    func pause(seconds: TimeInterval) {
        pauseUntil = max(pauseUntil,Date().addingTimeInterval(seconds))
        conservativeUntil = max(conservativeUntil,Date().addingTimeInterval(60))
        drain()
    }
    private func drain() {
        guard !pending.isEmpty else { return }
        let delay = pauseUntil.timeIntervalSinceNow
        if delay > 0 {
            if wake == nil {
                wake = Task {
                    try? await Task.sleep(for:.seconds(delay))
                    self.wake = nil; self.drain()
                }
            }
            return
        }
        let limit = Date() < conservativeUntil ? 1 : maximum
        while active < limit && !pending.isEmpty {
            active += 1; pending.removeFirst().1.resume()
        }
    }
}
enum CanvasParallel {
    static func map<Input:Sendable,Output:Sendable>(_ inputs:[Input],limit:Int,transform:@escaping @Sendable (Input) async throws -> Output) async throws -> [Output] {
        try await withThrowingTaskGroup(of:(Int,Output).self) { group in
            var next = 0, ordered = Array<Output?>(repeating:nil,count:inputs.count)
            for _ in 0..<min(max(1,limit),inputs.count) {
                let index = next; next += 1
                group.addTask { try Task.checkCancellation(); return (index,try await transform(inputs[index])) }
            }
            while let (index,result) = try await group.next() {
                ordered[index] = result
                if next < inputs.count {
                    let index = next; next += 1
                    group.addTask { try Task.checkCancellation(); return (index,try await transform(inputs[index])) }
                }
            }
            return ordered.map { $0! }
        }
    }
}
enum CanvasNetworking {
    static func shouldRetry(status:Int,body:Data) -> Bool {
        [408,429,500,502,503,504].contains(status) || (status == 403 && String(decoding:body.prefix(4096),as:UTF8.self).lowercased().contains("rate limit exceeded"))
    }
    static func delay(_ response:HTTPURLResponse,attempt:Int,now:Date) -> TimeInterval {
        let backoff = pow(2,Double(attempt))
        guard let raw = response.value(forHTTPHeaderField:"Retry-After") else { return backoff }
        if let seconds = TimeInterval(raw) { return max(backoff,seconds) }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier:"en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT:0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return max(backoff,formatter.date(from:raw)?.timeIntervalSince(now) ?? 0)
    }
    private static func run<Value:Sendable>(discard:@Sendable (Value)->Void = { _ in },operation:@Sendable () async throws -> (Value,HTTPURLResponse,Data)) async throws -> (Value,HTTPURLResponse) {
        for attempt in 0..<4 {
            try await CanvasRequestGate.shared.acquire()
            let value: Value, response: HTTPURLResponse, probe: Data
            do {
                try Task.checkCancellation()
                (value,response,probe) = try await operation()
            } catch {
                await CanvasRequestGate.shared.release()
                if Task.isCancelled { throw CancellationError() }
                let transient: Set<URLError.Code> = [.timedOut,.networkConnectionLost,.cannotConnectToHost,.dnsLookupFailed]
                if attempt < 3, let failure = error as? URLError, transient.contains(failure.code) {
                    try await Task.sleep(for:.seconds(pow(2,Double(attempt)) + Double.random(in:0...0.25))); continue
                }
                throw error
            }
            let retry = shouldRetry(status:response.statusCode,body:probe)
            let wait = retry ? delay(response,attempt:attempt,now:Date()) + Double.random(in:0...0.25) : 0
            // Install cooldown while this permit is still held; release must not admit another request first.
            if retry && (response.statusCode == 429 || response.statusCode == 403) { await CanvasRequestGate.shared.pause(seconds:wait) }
            await CanvasRequestGate.shared.release()
            if retry {
                if attempt < 3 {
                    discard(value)
                    if response.statusCode != 429 && response.statusCode != 403 { try await Task.sleep(for:.seconds(wait)) }
                    continue
                }
            }
            if Task.isCancelled { discard(value); throw CancellationError() }
            return (value,response)
        }
        throw CanvasAPIError.invalidResponse
    }
    static func data(for request:URLRequest,session:URLSession) async throws -> (Data,HTTPURLResponse) {
        try await run {
            let (data,response) = try await session.data(for:request)
            guard let http = response as? HTTPURLResponse else { throw CanvasAPIError.invalidResponse }
            return (data,http,data)
        }
    }
    static func download(for request:URLRequest,session:URLSession) async throws -> (URL,HTTPURLResponse) {
        try await run(discard:{ try? FileManager.default.removeItem(at:$0) }) {
            let (url,response) = try await session.download(for:request)
            guard let http = response as? HTTPURLResponse else { try? FileManager.default.removeItem(at:url); throw CanvasAPIError.invalidResponse }
            let probe: Data
            if http.statusCode == 403, let handle = try? FileHandle(forReadingFrom:url) { probe = (try? handle.read(upToCount:4096)) ?? Data(); try? handle.close() }
            else { probe = Data() }
            return (url,http,probe)
        }
    }
}
