import Foundation

struct CanvasModuleItem: Codable, Sendable, Identifiable {
    var id: Int
    var module_id: Int
    var title: String
    var type: String
    var content_id: Int?
    var page_url: String?
    var external_url: String?
    var html_url: String?
}
struct CanvasModule: Codable, Sendable, Identifiable {
    var id: Int
    var name: String
    var position: Int
    var items: [CanvasModuleItem] = []
    enum CodingKeys: String, CodingKey { case id, name, position, items }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        position = try c.decodeIfPresent(Int.self, forKey: .position) ?? 0
        items = try c.decodeIfPresent([CanvasModuleItem].self, forKey: .items) ?? []
    }
}
actor ModuleMaterialService {
    let directory: URL
    let api: FeedbackAPI
    let downloads: FeedbackFiles
    init(directory: URL, api: FeedbackAPI = FeedbackAPI()) {
        self.directory = directory; self.api = api
        downloads = FeedbackFiles(directory: directory, allowsHTMLTeachingFiles:true)
    }
    private func list<T: Decodable>(_ path: String, token: String) async throws -> [T] {
        let initial = URL(string: "https://canvas.sydney.edu.au" + path)!
        var next: URL? = initial, seen = Set<URL>(), result: [T] = []
        while let url = next {
            try Task.checkCancellation()
            guard url.path == initial.path, url.host == initial.host, url.scheme == "https", seen.insert(url).inserted else { throw FeedbackError.invalidData }
            let (data,response) = try await api.get(url, token: token)
            result += try JSONDecoder().decode([T].self, from: data)
            next = nil
            for part in (response.value(forHTTPHeaderField:"Link") ?? "").components(separatedBy:",") where part.contains("rel=\"next\"") {
                guard let a = part.firstIndex(of:"<"), let b = part.firstIndex(of:">"), a < b else { throw FeedbackError.invalidData }
                next = URL(string:String(part[part.index(after:a)..<b]),relativeTo:url)?.absoluteURL
            }
        }
        return result
    }
    private func cache(_ name: String) -> URL { directory.appendingPathComponent(name + ".json") }
    private func persist<T: Encodable>(_ value: T, name: String) throws {
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        let url = cache(name); try JSONEncoder().encode(value).write(to:url,options:.atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path)
    }
    func cachedCatalog(courseID: Int) -> [CanvasModule]? {
        (try? Data(contentsOf:cache("catalog-\(courseID)"))).flatMap { try? JSONDecoder().decode([CanvasModule].self,from:$0) }
    }
    func catalog(courseID: Int, token: String) async throws -> [CanvasModule] {
        var modules: [CanvasModule] = try await list("/api/v1/courses/\(courseID)/modules?per_page=100",token:token)
        guard Set(modules.map(\.id)).count == modules.count, modules.allSatisfy({ $0.id > 0 }) else { throw FeedbackError.invalidData }
        modules = try await CanvasParallel.map(modules,limit:4) { module in
            var module = module
            module.items = try await self.list("/api/v1/courses/\(courseID)/modules/\(module.id)/items?per_page=100",token:token)
            guard module.items.allSatisfy({ $0.module_id == module.id }) else { throw FeedbackError.invalidData }
            return module
        }
        modules.sort { $0.position < $1.position }
        try persist(modules,name:"catalog-\(courseID)")
        return modules
    }
    func prepare(_ module: CanvasModule, courseID: Int, course: String, token: String?) async throws -> AssignmentAssistPlan {
        let name = "module-\(courseID)-\(module.id)"
        let previous = (try? Data(contentsOf:cache(name))).flatMap { try? JSONDecoder().decode(AssignmentAssistPlan.self,from:$0) }
        guard let token, !token.isEmpty else {
            guard var previous else { throw FeedbackError.unavailable("Connect to Canvas to collect this module. Previously downloaded modules remain available.") }
            previous.warnings.append("Offline: using the last collected module."); return previous
        }
        var plan = AssignmentAssistPlan(course:course,title:module.name,courseID:courseID,assignmentID:module.id)
        plan.links = ["https://canvas.sydney.edu.au/courses/\(courseID)/modules/\(module.id)"]
        let catalog = cachedCatalog(courseID:courseID) ?? []
        let otherModulePages = Set(catalog.filter { $0.id != module.id }.flatMap(\.items).compactMap(\.page_url))
        var incompletePages = false
        var fileIDs: [Int] = [], pageQueue: [String] = [], visitedPages = Set<String>()
        for item in module.items {
            switch item.type {
            case "File": if let id = item.content_id, id > 0 { if !fileIDs.contains(id) { fileIDs.append(id) } }
            case "Page": if let page = item.page_url { pageQueue.append(page) }
            case "SubHeader": break
            default:
                if let link = item.external_url ?? item.html_url, let clean = AssignmentAssistContent.cleanURL(link) { plan.links.append(clean.absoluteString) }
                plan.warnings.append(item.title + ": Canvas " + item.type + " item is linked, not downloaded as a teaching file.")
            }
        }
        while !pageQueue.isEmpty && visitedPages.count < 100 {
            try Task.checkCancellation()
            let slug = pageQueue.removeFirst()
            guard visitedPages.insert(slug).inserted else { continue }
            var components = URLComponents(); components.scheme = "https"; components.host = "canvas.sydney.edu.au"
            components.path = "/api/v1/courses/\(courseID)/pages/" + slug
            do {
                let object = try FeedbackAPI.object(try await api.get(components.url!,token:token).0)
                guard object["published"] as? Bool != false, object["locked_for_user"] as? Bool != true else { throw CanvasAPIError.forbidden }
                let html = object["body"] as? String ?? "", title = object["title"] as? String ?? slug
                let source = "https://canvas.sydney.edu.au/courses/\(courseID)/pages/" + slug
                plan.texts.append(AssistText(name:AssignmentAssistContent.safeName("Page - " + title + " - \(visitedPages.count).txt"),text:course + " — " + module.name + "\n" + title + "\nSource: " + source + "\n\n" + AssignmentAssistContent.text(html)))
                plan.links.append(source)
                for raw in AssignmentAssistContent.references(html) {
                    guard let url = AssignmentAssistContent.cleanURL(raw) else { continue }
                    plan.links.append(url.absoluteString)
                    guard url.host == "canvas.sydney.edu.au" else { continue }
                    let parts = url.path.split(separator:"/").map(String.init)
                    if parts.count >= 4, parts[0] == "courses", parts[1] == String(courseID) {
                        if parts[2] == "files", let id = Int(parts[3]), id > 0 { if !fileIDs.contains(id) { fileIDs.append(id) } }
                        if parts[2] == "pages", !otherModulePages.contains(parts[3]) { pageQueue.append(parts[3]) }
                    } else if parts.count >= 2, parts[0] == "files", let id = Int(parts[1]), id > 0 { if !fileIDs.contains(id) { fileIDs.append(id) } }
                }
            } catch is CancellationError { throw CancellationError() }
            catch CanvasAPIError.invalidKey { if var previous { previous.warnings.append("Canvas authentication failed; using saved module materials."); return previous }; throw CanvasAPIError.invalidKey }
            catch CanvasAPIError.server(429) { if var previous { previous.warnings.append("Canvas is limiting requests; using saved module materials."); return previous }; throw CanvasAPIError.server(429) }
            catch {
                incompletePages = true
                let source = "https://canvas.sydney.edu.au/courses/\(courseID)/pages/" + slug
                plan.links.append(source)
                let saved = previous?.texts.filter { $0.text.contains("Source: " + source + "\n") } ?? []
                plan.texts += saved
                plan.warnings.append("Page \(slug): unavailable from Canvas." + (saved.isEmpty ? " The source remains linked." : " Using its saved text and linked files."))
            }
        }
        if incompletePages, let previous {
            func source(_ text: AssistText) -> String { text.text.components(separatedBy:"\n").first { $0.hasPrefix("Source: ") } ?? text.name }
            let refreshedSources = Set(plan.texts.map(source))
            plan.texts += previous.texts.filter { !refreshedSources.contains(source($0)) }
            for file in previous.files where !fileIDs.contains(file.id) { fileIDs.append(file.id) }
            plan.links += previous.links
        }
        if !pageQueue.isEmpty { plan.warnings.append("Linked-page limit reached (100). Remaining pages are available in Canvas.") }
        if fileIDs.count > 1000 { plan.warnings.append("File limit reached (1,000). Remaining files are available in Canvas.") }
        do {
            let results = try await CanvasParallel.map(Array(fileIDs.prefix(1000)),limit:4) { id in
                try await self.resolveFile(id:id,courseID:courseID,token:token,previous:previous)
            }
            plan.files += results.compactMap(\.0); plan.warnings += results.flatMap(\.1)
        } catch is CancellationError { throw CancellationError() }
        catch CanvasAPIError.invalidKey { if var previous { previous.warnings.append("Canvas authentication failed; using saved module materials."); return previous }; throw CanvasAPIError.invalidKey }
        catch CanvasAPIError.server(429) { if var previous { previous.warnings.append("Canvas is limiting requests; using saved module materials."); return previous }; throw CanvasAPIError.server(429) }
        plan.links = Array(Set(plan.links)).sorted()
        try persist(plan,name:name); return plan
    }
    private func resolveFile(id:Int,courseID:Int,token:String,previous:AssignmentAssistPlan?) async throws -> (FeedbackAttachment?,[String]) {
        do {
            try Task.checkCancellation()
            let object = try await fileMetadata(id:id,courseID:courseID,token:token)
            // Hidden-from-Files resources are valid when explicitly linked; locked resources stay unavailable.
            guard object["id"] as? Int == id, object["locked_for_user"] as? Bool != true,
                  let url = object["url"] as? String, let parsed = URL(string:url), parsed.scheme == "https" else { throw CanvasAPIError.forbidden }
            var file = FeedbackAttachment(id:id,name:object["display_name"] as? String ?? object["filename"] as? String ?? "File \(id)",url:url,contentType:object["content-type"] as? String ?? "application/octet-stream",size:object["size"] as? Int ?? 0,updatedAt:object["updated_at"] as? String)
            if let cached = previous?.files.first(where: { $0.sameRevision(as:file) }) { file.localPath = cached.localPath; file.contentHash = cached.contentHash; file.cachedSize = cached.cachedSize }
            return (file,[])
        } catch is CancellationError { throw CancellationError() }
        catch CanvasAPIError.invalidKey { throw CanvasAPIError.invalidKey }
        catch CanvasAPIError.server(429) { throw CanvasAPIError.server(429) }
        catch {
            if Task.isCancelled { throw CancellationError() }
            let cached = previous?.files.first(where: { $0.id == id && FeedbackFiles.localURL($0,directory:directory) != nil })
            return (cached,["Canvas file \(id): " + error.localizedDescription] + (cached.map { ["Using the saved copy of " + $0.name + "."] } ?? []))
        }
    }
    private func fileMetadata(id:Int,courseID:Int,token:String) async throws -> [String:Any] {
        do { return try FeedbackAPI.object(try await api.get(URL(string:"https://canvas.sydney.edu.au/api/v1/courses/\(courseID)/files/\(id)")!,token:token).0) }
        catch CanvasAPIError.forbidden { }
        catch CanvasAPIError.server(404) { }
        // Only an explicitly referenced file ID; Canvas still checks the student's permission.
        return try FeedbackAPI.object(try await api.get(URL(string:"https://canvas.sydney.edu.au/api/v1/files/\(id)")!,token:token).0)
    }
    func ready(_ plan: AssignmentAssistPlan, token: String?) async throws -> ([AssignmentMaterial], AssignmentAssistPlan) {
        var plan = plan
        var materials = try AssignmentMaterialFiles.writeTexts(plan,directory:directory.appendingPathComponent("Ready"))
        let downloads = self.downloads, directory = self.directory
        let results = try await CanvasParallel.map(plan.files,limit:4) { file -> (FeedbackAttachment,AssignmentMaterial) in
            do {
                let saved = try await downloads.obtain(file,token:token ?? "")
                guard let url = FeedbackFiles.localURL(saved,directory:directory) else { throw FeedbackError.invalidData }
                return (saved,AssignmentMaterial(id:String(saved.id),name:saved.name,url:url,note:"Ready to drag"))
            } catch is CancellationError { throw CancellationError() }
            catch {
                if Task.isCancelled { throw CancellationError() }
                return (file,AssignmentMaterial(id:String(file.id),name:file.name,url:nil,note:error.localizedDescription))
            }
        }
        plan.files = results.map(\.0); materials += results.map(\.1)
        try persist(plan,name:"module-\(plan.courseID)-\(plan.assignmentID)")
        return (materials,plan)
    }
    nonisolated static func numberedName(_ value: String, number: Int) -> String {
        let safe = AssignmentAssistContent.safeName(value)
        let ext = (safe as NSString).pathExtension
        var stem = (safe as NSString).deletingPathExtension
        let suffix = " (\(number))" + (ext.isEmpty ? "" : "." + ext)
        while stem.utf8.count + suffix.utf8.count > 180 { stem.removeLast() }
        return stem + suffix
    }
    nonisolated static func export(_ modules: [(CanvasModule,[AssignmentMaterial],AssignmentAssistPlan)], course: String, to downloads: URL) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at:downloads,withIntermediateDirectories:true)
        let stage = downloads.appendingPathComponent(".ModuleFiles-" + UUID().uuidString)
        try fm.createDirectory(at:stage,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
        defer { try? fm.removeItem(at:stage) }
        for (module,materials,plan) in modules {
            try Task.checkCancellation()
            let folder = stage.appendingPathComponent(AssignmentAssistContent.safeName(String(format:"%02d",module.position) + " - " + module.name + " (\(module.id))"))
            try fm.createDirectory(at:folder,withIntermediateDirectories:false)
            var usedNames: Set<String> = ["collection notes.txt"]
            for material in materials {
                guard let source = material.url else { continue }
                let name = AssignmentAssistContent.safeName(material.name)
                var destination = folder.appendingPathComponent(name), number = 2
                while usedNames.contains(destination.lastPathComponent.lowercased()) || fm.fileExists(atPath:destination.path) {
                    try Task.checkCancellation()
                    destination = folder.appendingPathComponent(numberedName(name,number:number)); number += 1
                }
                usedNames.insert(destination.lastPathComponent.lowercased())
                try fm.copyItem(at:source,to:destination)
                try fm.setAttributes([.posixPermissions:0o600],ofItemAtPath:destination.path)
            }
            let notes = [course + " — " + module.name,"Teaching materials only. External tools, assignments, discussions and quizzes are linked in Source links.txt."] + plan.warnings + materials.filter { $0.url == nil }.map { $0.name + ": " + $0.note }
            try notes.joined(separator:"\n").write(to:folder.appendingPathComponent("Collection notes.txt"),atomically:true,encoding:.utf8)
        }
        let base = AssignmentAssistContent.safeName(course + " - " + (modules.count == 1 ? modules[0].0.name : "All modules"))
        var destination = downloads.appendingPathComponent(base), number = 2
        while fm.fileExists(atPath:destination.path) { destination = downloads.appendingPathComponent(base + " (\(number))"); number += 1 }
        try Task.checkCancellation(); try fm.moveItem(at:stage,to:destination); return destination
    }
}
