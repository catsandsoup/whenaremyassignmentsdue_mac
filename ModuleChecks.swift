import Foundation
final class ModuleProtocol: URLProtocol, @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var offline = false
    nonisolated(unsafe) static var paths: [String] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if Self.offline { client?.urlProtocol(self,didFailWithError:URLError(.notConnectedToInternet)); return }
        let url = request.url!; Self.lock.lock(); Self.paths.append(url.path); Self.lock.unlock()
        var status = 200
        var body = "[]", headers: [String:String] = [:]
        if url.path.hasSuffix("/modules") {
            if url.query?.contains("page=2") == true { body = #"[{"id":2,"name":"Week 2","position":2}]"# }
            else { body = #"[{"id":1,"name":"Week 1","position":1}]"#; headers["Link"] = "<https://canvas.sydney.edu.au/api/v1/courses/42/modules?page=2>; rel=\"next\"" }
        } else if url.path.contains("/modules/1/items") { body = #"[{"id":10,"module_id":1,"title":"Lecture","type":"File","content_id":100},{"id":11,"module_id":1,"title":"Lecture again","type":"File","content_id":100},{"id":13,"module_id":1,"title":"Reading page","type":"Page","page_url":"reading"},{"id":12,"module_id":1,"title":"Reading","type":"ExternalUrl","external_url":"https://example.com/reading?token=secret"}]"# }
        else if url.path.contains("/modules/2/items") { body = #"[{"id":20,"module_id":2,"title":"Locked","type":"File","content_id":101}]"# }
        else if url.path.hasSuffix("/pages/reading") { body = #"{"title":"Reading page","published":true,"body":"<p>Read this example</p><a href=\"/courses/42/files/99\">Worksheet</a>"}"# }
        else if url.path.hasSuffix("/files/99") { body = #"{"id":99,"display_name":"Example.html","url":"https://canvas.sydney.edu.au/files/99/download","content-type":"text/html","size":15}"# }
        else if url.path == "/api/v1/courses/42/files/100" { status = 403; body = "Forbidden" }
        else if url.path.hasSuffix("/files/100") { body = #"{"id":100,"hidden_for_user":true,"locked_for_user":false,"display_name":"Lecture.txt","url":"https://canvas.sydney.edu.au/files/100/download","content-type":"text/plain","size":5}"# }
        else if url.path.hasSuffix("/files/101") { body = #"{"id":101,"display_name":"Locked.pdf","locked_for_user":true}"# }
        else if url.path == "/files/100/download" { body = "hello" }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url:url,statusCode:status,httpVersion:nil,headerFields:headers)!, cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@main struct ModuleChecks {
 static func main() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [ModuleProtocol.self]
    let session = URLSession(configuration:config)
    let service = ModuleMaterialService(directory:root, api:FeedbackAPI(session:session))
    let modules = try await service.catalog(courseID:42,token:"synthetic")
    precondition(modules.map(\.id) == [1,2], "all module pages and order")
    precondition(modules[0].items.count == 4)
    let plan = try await service.prepare(modules[0],courseID:42,course:"TEST1000",token:"synthetic")
    precondition(plan.files.map(\.id) == [100,99], "deduplicate while preserving module discovery order")
    precondition(plan.links.contains("https://example.com/reading"), "strip sensitive query selectors")
    let locked = try await service.prepare(modules[1],courseID:42,course:"TEST1000",token:"synthetic")
    precondition(locked.files.isEmpty && !locked.warnings.isEmpty, "locked is never a fake ready file")
    var cachedPlan = plan
    for i in cachedPlan.files.indices {
        let bytes = Data((cachedPlan.files[i].id == 99 ? "<html>Example</html>" : "hello").utf8)
        cachedPlan.files[i] = try await service.downloads.commit(bytes,file:cachedPlan.files[i])
    }
    _ = try await service.ready(cachedPlan,token:nil)
    ModuleProtocol.offline = true
    let offlinePlan = try await service.prepare(modules[0],courseID:42,course:"TEST1000",token:"synthetic")
    precondition(offlinePlan.texts.map(\.text) == plan.texts.map(\.text), "offline refresh retains page text")
    precondition(Set(offlinePlan.files.map(\.id)) == [100,99], "offline refresh retains page-linked file discoveries")
    let offlineReady = try await service.ready(offlinePlan,token:nil).0
    precondition(offlineReady.filter { $0.url != nil }.count == 4, "cached files/pages/source links stay reusable offline")
    ModuleProtocol.offline = false
    let bytes = root.appendingPathComponent("Lecture.txt"); try Data("hello".utf8).write(to:bytes)
    let longName = String(repeating:"a",count:176) + ".txt"
    let numbered = ModuleMaterialService.numberedName(longName,number:2)
    precondition(numbered.utf8.count <= 180 && numbered.hasSuffix(" (2).txt"), "collision suffix survives name limit")
    let material = AssignmentMaterial(id:"100",name:"Lecture.txt",url:bytes)
    let output = root.appendingPathComponent("Downloads")
    let longFile = AssignmentMaterial(id:"long",name:longName,url:bytes)
    let a = try ModuleMaterialService.export([(modules[0], [material,longFile,longFile], plan), (modules[1],[],locked)],course:"TEST1000",to:output)
    let b = try ModuleMaterialService.export([(modules[0], [material], plan)],course:"TEST1000",to:output)
    precondition(a != b, "repeated exports do not overwrite")
    let files = FileManager.default.enumerator(at:a,includingPropertiesForKeys:nil)!.allObjects as! [URL]
    let copied = files.first { $0.lastPathComponent == "Lecture.txt" }!
    let copiedBytes = try Data(contentsOf:copied); precondition(copiedBytes == Data("hello".utf8))
    precondition(files.contains { $0.lastPathComponent == "Collection notes.txt" })
    let cached = await service.cachedCatalog(courseID:42)
    precondition(cached?.count == 2)
    precondition(ModuleProtocol.paths.allSatisfy { $0.hasPrefix("/api/v1/courses/42/") || $0 == "/api/v1/files/100" }, "API stays in selected course")
    print("PASS: modules pagination, ordered deduplication, page traversal, locked resources, HTML teaching files, offline retention, exact-byte exports and long duplicate names")
 }
}
