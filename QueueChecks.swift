import Foundation
actor QueueProbe {
    var active = 0, peak = 0
    func work(_ value: Int) async throws -> Int {
        active += 1; peak = max(peak,active)
        try await Task.sleep(for:.milliseconds(20))
        active -= 1; return value * 2
    }
}
final class QueueProtocol: URLProtocol, @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var counts: [String:Int] = [:]
    nonisolated(unsafe) static var active = 0
    nonisolated(unsafe) static var peak = 0
    nonisolated(unsafe) static var throttledAt: Date?
    nonisolated(unsafe) static var earlyStarts = 0
    override class func canInit(with request:URLRequest) -> Bool { true }
    override class func canonicalRequest(for request:URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!, path = url.path
        Self.lock.lock(); if path.hasPrefix("/burst/"), let at = Self.throttledAt, Date().timeIntervalSince(at) < 0.8 { Self.earlyStarts += 1 }; Self.active += 1; Self.peak = max(Self.peak,Self.active); Self.counts[path,default:0] += 1; let attempt = Self.counts[path]!; Self.lock.unlock()
        DispatchQueue.global().asyncAfter(deadline:.now()+0.03) {
            let isBurst = path.hasPrefix("/burst/") && attempt == 1
            let status = isBurst ? 429 : path == "/deny" ? 403 : path == "/retry" && attempt == 1 ? 503 : path == "/throttle" && attempt == 1 ? 403 : 200
            let body = path == "/throttle" && status == 403 ? "Rate Limit Exceeded" : "result"
            Self.lock.lock(); if isBurst && Self.throttledAt == nil { Self.throttledAt = Date() }; Self.active -= 1; Self.lock.unlock()
            self.client?.urlProtocol(self,didReceive:HTTPURLResponse(url:url,statusCode:status,httpVersion:nil,headerFields:["Retry-After":"0"])!,cacheStoragePolicy:.notAllowed)
            self.client?.urlProtocol(self,didLoad:Data(body.utf8)); self.client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}
@main struct QueueChecks {
 static func main() async throws {
    let probe = QueueProbe()
    let results = try await CanvasParallel.map(Array(0..<12),limit:3) { try await probe.work($0) }
    precondition(results == Array(0..<12).map { $0 * 2 }, "concurrent completion retains source order")
    let peak = await probe.peak; precondition(peak == 3,"bounded work actually overlaps")
    let gate = CanvasRequestGate(limit:2)
    try await gate.acquire(); try await gate.acquire()
    let waiter = Task { try await gate.acquire() }
    waiter.cancel()
    do { try await waiter.value; preconditionFailure("cancelled queued work acquired a slot") } catch is CancellationError { }
    await gate.release(); await gate.release()
    try await gate.acquire(); await gate.release()
    let http = HTTPURLResponse(url:URL(string:"https://canvas.sydney.edu.au/api/v1/test")!,statusCode:429,httpVersion:nil,headerFields:["Retry-After":"3"])!
    precondition(CanvasNetworking.delay(http,attempt:0,now:Date()) >= 3)
    precondition(CanvasNetworking.shouldRetry(status:403,body:Data("{\"message\":\"Rate Limit Exceeded\"}".utf8)))
    precondition(!CanvasNetworking.shouldRetry(status:403,body:Data("Forbidden".utf8)))
    precondition(CanvasNetworking.shouldRetry(status:503,body:Data()))
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [QueueProtocol.self]
    let session = URLSession(configuration:config)
    _ = try await CanvasParallel.map(Array(0..<12),limit:12) { index in
        try await CanvasNetworking.data(for:URLRequest(url:URL(string:"https://canvas.sydney.edu.au/work/\(index)")!),session:session).0
    }
    precondition(QueueProtocol.peak <= 4 && QueueProtocol.peak > 1,"shared request cap applies across independent callers")
    _ = try await CanvasParallel.map(Array(0..<12),limit:12) { index in
        try await CanvasNetworking.data(for:URLRequest(url:URL(string:"https://canvas.sydney.edu.au/burst/\(index)")!),session:session).0
    }
    precondition(QueueProtocol.earlyStarts == 0,"queued calls must pause before a throttled slot is released")
    for path in ["retry","deny","throttle"] {
        _ = try await CanvasNetworking.data(for:URLRequest(url:URL(string:"https://canvas.sydney.edu.au/" + path)!),session:session)
    }
    precondition(QueueProtocol.counts["/retry"] == 2 && QueueProtocol.counts["/throttle"] == 2)
    precondition(QueueProtocol.counts["/deny"] == 1,"ordinary permission denial must not be retried")
    print("PASS: concurrent ordered work, bounded overlap, cancelled queue recovery, Canvas 403/429 throttling and Retry-After")
 }
}
