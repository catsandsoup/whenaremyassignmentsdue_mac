import Foundation

struct AssistText: Codable, Sendable {
    var name: String
    var text: String
}
struct AssignmentAssistPlan: Codable, Sendable {
    var course: String
    var title: String
    var courseID: Int
    var assignmentID: Int
    var texts: [AssistText] = []
    var files: [FeedbackAttachment] = []
    var linkedFileIDs: Set<Int> = []
    var links: [String] = []
    var outlineURL: String = ""
    var warnings: [String] = []
    var unavailableTextNames: Set<String>? = nil
}
enum AssignmentAssistContent {
    static func rubric(_ item: FeedbackItem) -> String {
        var lines = [item.course + " — " + item.originalTitle, "Marking criteria: " + item.rubricTitle, ""]
        if item.rubric.isEmpty { lines.append("No structured rubric was supplied. Check the brief and teaching documents for a rubric.") }
        for criterion in item.rubric {
            lines += [criterion.description, criterion.longDescription]
            if !item.hideRubricPoints, let points = criterion.points { lines.append("Maximum: " + FeedbackFormat.number(points)) }
            if criterion.usesRange { lines.append("Rating points use ranges.") }
            for rating in criterion.ratings {
                lines.append(rating.description + (!item.hideRubricPoints ? rating.points.map { " (" + FeedbackFormat.number($0) + ")" } ?? "" : ""))
                lines.append(rating.longDescription)
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
    static func cleanURL(_ raw: String) -> URL? {
        guard var parts = URLComponents(string: decode(raw)), ["https", "http"].contains(parts.scheme?.lowercased() ?? ""), parts.host != nil,
              parts.user == nil, parts.password == nil else { return nil }
        if parts.host == "canvas.sydney.edu.au" { parts.query = nil }
        else {
            // Keep common public outline selectors; signed/authentication query values never enter exports.
            let selectors: Set<String> = ["year", "semester", "term", "unit", "unit_code", "code", "id", "edition", "page"]
            let query = parts.queryItems?.filter { selectors.contains($0.name.lowercased()) }
            parts.queryItems = query?.isEmpty == false ? query : nil
        }
        parts.fragment = nil
        if parts.host == "canvas.sydney.edu.au", parts.path.hasPrefix("/api/v1/") { parts.path = String(parts.path.dropFirst(7)) }
        return parts.url
    }
    static func safeName(_ value: String) -> String {
        let cleaned = String(value.map { "/\\:\0".contains($0) || $0.isNewline || $0.asciiValue.map({ $0 < 32 }) == true ? "_" : $0 }).trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        let ext = (cleaned as NSString).pathExtension
        let suffix = !ext.isEmpty && ext.utf8.count <= 16 ? "." + ext : ""
        var base = suffix.isEmpty ? cleaned : String(cleaned.dropLast(suffix.count))
        while base.utf8.count + suffix.utf8.count > 180 { base.removeLast() }
        let result = base + suffix
        return result.isEmpty ? "Document" : result
    }

    static func decode(_ value: String) -> String {
        var text = value
        for (entity, char) in [("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " "), ("&ndash;", "–"), ("&mdash;", "—"), ("&rsquo;", "’"), ("&lsquo;", "‘"), ("&ldquo;", "“"), ("&rdquo;", "”")] { text = text.replacingOccurrences(of: entity, with: char) }
        if let regex = try? NSRegularExpression(pattern: "&#(x[0-9a-fA-F]+|[0-9]+);") {
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
                guard let range = Range(match.range, in: text), let number = Range(match.range(at: 1), in: text) else { continue }
                let raw = String(text[number]); let value = raw.hasPrefix("x") ? UInt32(raw.dropFirst(), radix: 16) : UInt32(raw)
                if let value, let scalar = UnicodeScalar(value) { text.replaceSubrange(range, with: String(scalar)) }
            }
        }
        return text
    }
    static func references(_ html: String) -> [String] {
        let pattern = #"(?i)(?:href|src|data-api-endpoint)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
            for index in 1...3 where match.range(at: index).location != NSNotFound {
                if let range = Range(match.range(at: index), in: html), let url = URL(string: decode(String(html[range])), relativeTo: URL(string: "https://canvas.sydney.edu.au")) { return url.absoluteURL.absoluteString }
            }
            return nil
        } + (cleanURL(html).map { [$0.absoluteString] } ?? [])
    }
    static func text(_ html: String) -> String {
        var text = html.replacingOccurrences(of: #"(?is)<(script|style)\b[^>]*>.*?</\1\s*>"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)<(?:br|/p|/div|/li|/h[1-6]|/tr|/section)\b[^>]*>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        return decode(text).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func outlineReference(_ html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"(?is)<a\b[^>]*>.*?</a>"#) else { return nil }
        for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range, in: html) else { continue }
            let anchor = String(html[range])
            let label = text(anchor).lowercased().replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            if label.contains("unit outline") || label.contains("unit of study outline") || label.contains("unit of study outlines") {
                if let link = references(anchor).compactMap({ cleanURL($0)?.absoluteString }).first { return link }
            }
        }
        return references(html).compactMap { cleanURL($0)?.absoluteString }.first { $0.contains("/units/") || $0.contains("unit-of-study-outline") }
    }
    static func plan(_ item: FeedbackItem) -> AssignmentAssistPlan {
        var plan = AssignmentAssistPlan(course: item.course, title: item.originalTitle, courseID: item.courseID, assignmentID: item.assignmentID)
        let object = item.sourceAssignment.flatMap { try? FeedbackAPI.object($0) } ?? [:]
        let html = object["description"] as? String ?? ""
        var brief = [item.course + " — " + item.originalTitle, "Source: https://canvas.sydney.edu.au/courses/\(item.courseID)/assignments/\(item.assignmentID)"]
        if let due = object["due_at"] as? String { brief.append("Due: " + FeedbackFormat.time(due)) }
        if let points = object["points_possible"] as? Double { brief.append("Points possible: " + FeedbackFormat.number(points)) }
        if let types = object["submission_types"] as? [String] { brief.append("Submission types: " + types.joined(separator: ", ")) }
        if let extensions = object["allowed_extensions"] as? [String], !extensions.isEmpty { brief.append("Allowed file types: " + extensions.joined(separator: ", ")) }
        brief += ["", html.isEmpty ? "No assignment description was supplied. Check the linked teaching documents." : text(html)]
        plan.unavailableTextNames = []
        if html.isEmpty { plan.unavailableTextNames?.insert("01-Assignment-brief.txt") }
        if item.rubric.isEmpty { plan.unavailableTextNames?.insert("02-Marking-rubric.txt") }
        plan.texts = [AssistText(name: "01-Assignment-brief.txt", text: brief.joined(separator: "\n")), AssistText(name: "02-Marking-rubric.txt", text: rubric(item))]
        plan.outlineURL = outlineReference(html) ?? ""
        plan.links = references(html).compactMap { cleanURL($0)?.absoluteString } + ["https://canvas.sydney.edu.au/courses/\(item.courseID)/assignments/\(item.assignmentID)", "https://canvas.sydney.edu.au/courses/\(item.courseID)/assignments/syllabus"]
        return plan
    }
}

actor AssignmentAssistService {
    let directory: URL
    let api: FeedbackAPI
    let downloads: FeedbackFiles
    init(directory: URL, api: FeedbackAPI = FeedbackAPI()) {
        self.directory = directory; self.api = api
        downloads = FeedbackFiles(directory: directory)
    }
    private func cacheURL(_ item: FeedbackItem) -> URL {
        directory.appendingPathComponent("\(item.courseID)-\(item.assignmentID).json")
    }
    func prepare(_ item: FeedbackItem, token: String?) async throws -> AssignmentAssistPlan {
        let cache = cacheURL(item)
        let previous = (try? Data(contentsOf: cache)).flatMap { try? JSONDecoder().decode(AssignmentAssistPlan.self, from: $0) }
        var plan = previous ?? AssignmentAssistContent.plan(item)
        guard let token, !token.isEmpty else {
            plan.warnings.append("Canvas could not be accessed with the saved credential. Cached requirements remain available; unavailable materials are listed here.")
            return plan
        }
        var complete = true
        do {
            let data = try await api.get(URL(string: "https://canvas.sydney.edu.au/api/v1/courses/\(item.courseID)/assignments/\(item.assignmentID)")!, token: token).0
            let a = try FeedbackAPI.object(data)
            guard a["id"] as? Int == item.assignmentID, a["published"] as? Bool != false else { throw FeedbackError.invalidData }
            var updated = item; updated.sourceAssignment = data
            let stub = try JSONSerialization.data(withJSONObject: ["assignment_id": item.assignmentID, "user_id": item.userID, "workflow_state": "unsubmitted"])
            let criteria = try FeedbackAPI.item(assignment: data, submission: stub, courseID: item.courseID, course: item.course, userID: item.userID, checkedAt: ISO8601DateFormatter().string(from: Date()))
            updated.rubric = criteria.rubric; updated.hideRubricPoints = criteria.hideRubricPoints; updated.rubricTitle = criteria.rubricTitle
            plan = AssignmentAssistContent.plan(updated)
        } catch is CancellationError { throw CancellationError() }
        catch { complete = false; plan.warnings.append("Assignment refresh unavailable. The saved brief and rubric are included when available.") }
        var htmls: [String] = []
        var needsCourseHome = false
        if let raw = item.sourceAssignment, let a = try? FeedbackAPI.object(raw), let html = a["description"] as? String { htmls.append(html) }
        // Use the refreshed brief for discovery too.
        htmls += plan.links
        do {
            let data = try await api.get(URL(string: "https://canvas.sydney.edu.au/api/v1/courses/\(item.courseID)?include[]=syllabus_body")!, token: token).0
            let course = try FeedbackAPI.object(data)
            guard course["id"] as? Int == item.courseID else { throw FeedbackError.invalidData }
            if let html = course["syllabus_body"] as? String, !html.isEmpty {
                plan.texts.removeAll { $0.name == "03-Course-syllabus.txt" }
                plan.texts.append(AssistText(name: "03-Course-syllabus.txt", text: AssignmentAssistContent.text(html)))
                htmls.append(html)
                if plan.outlineURL.isEmpty { plan.outlineURL = AssignmentAssistContent.outlineReference(html) ?? "" }
            } else { needsCourseHome = true; plan.warnings.append("Canvas did not provide a syllabus field; checking the course home page for the unit outline.") }
        } catch is CancellationError { throw CancellationError() }
        catch { complete = false; needsCourseHome = true; plan.warnings.append("Course syllabus unavailable. Available course home content and source links are retained.") }
        if needsCourseHome {
            do {
                let data = try await api.get(URL(string: "https://canvas.sydney.edu.au/api/v1/courses/\(item.courseID)/front_page")!, token: token).0
                let page = try FeedbackAPI.object(data)
                guard page["published"] as? Bool != false, page["locked_for_user"] as? Bool != true, let html = page["body"] as? String else { throw FeedbackError.invalidData }
                // The home page is navigation. Use its labelled outline link, without exporting
                // unrelated staff/help/navigation pages as assignment materials.
                if let outline = AssignmentAssistContent.outlineReference(html) {
                    if plan.outlineURL.isEmpty { plan.outlineURL = outline }
                    htmls.append(outline)
                }
            } catch is CancellationError { throw CancellationError() }
            catch { plan.warnings.append("Course home page unavailable; its linked materials could not be discovered.") }
        }
        // Resolve only documents referenced by this assessment, its syllabus or outline.
        var filesByID: [Int: FeedbackAttachment] = [:]
        var visited = Set<String>(), fileIDs = Set<Int>(), requestedPageNames = Set<String>()
        var queue = htmls.flatMap { AssignmentAssistContent.references($0) }
        while !queue.isEmpty {
            try Task.checkCancellation()
            let raw = queue.removeFirst()
            guard let url = AssignmentAssistContent.cleanURL(raw), visited.insert(url.absoluteString).inserted else { continue }
            plan.links.append(url.absoluteString)
            let parts = url.path.split(separator: "/").map(String.init)
            guard url.host == "canvas.sydney.edu.au" else { continue }
            let offset = parts.starts(with: ["api", "v1"]) ? 2 : 0
            let path = Array(parts.dropFirst(offset))
            if path.first == "files", path.count >= 2, let id = Int(path[1]) { fileIDs.insert(id) }
            else if path.count >= 4, path[0] == "courses", path[1] == String(item.courseID) {
                if path[2] == "files", let id = Int(path[3]) { fileIDs.insert(id) }
                else if path[2] == "pages" {
                    guard plan.texts.filter({ $0.name.hasPrefix("Page-") }).count < 30 else { plan.warnings.append("Linked-page collection stopped at 30 pages. Remaining source links are included for review."); continue }
                    let requestedName = "Page-" + AssignmentAssistContent.safeName(path[3]) + ".txt"
                    requestedPageNames.insert(requestedName)
                    do {
                        let endpoint = "https://canvas.sydney.edu.au/api/v1/courses/\(item.courseID)/pages/\(path[3])"
                        let data = try await api.get(URL(string: endpoint)!, token: token).0
                        let page = try FeedbackAPI.object(data)
                        guard page["published"] as? Bool != false, page["locked_for_user"] as? Bool != true else { throw FeedbackError.invalidData }
                        let html = page["body"] as? String ?? ""
                        let name = "Page-" + AssignmentAssistContent.safeName(path[3]) + ".txt"
                        plan.texts.removeAll { $0.name == name }
                        plan.texts.append(AssistText(name: name, text: (page["title"] as? String ?? path[3]) + "\nSource: https://canvas.sydney.edu.au/courses/\(item.courseID)/pages/\(path[3])\n\n" + AssignmentAssistContent.text(html)))
                        queue += AssignmentAssistContent.references(html)
                    } catch is CancellationError { throw CancellationError() }
                    catch { complete = false; plan.warnings.append("Linked page unavailable: " + url.absoluteString) }
                }
            }
        }
        let discoveryIDs = fileIDs.sorted()
        if discoveryIDs.count > 500 { plan.warnings.append("File discovery stopped at 500 files. Additional linked files were not collected.") }
        let prioritisedIDs = fileIDs.sorted()
        for id in prioritisedIDs.prefix(500) where filesByID[id] == nil {
            do {
                let data: Data
                do { data = try await api.get(URL(string: "https://canvas.sydney.edu.au/api/v1/courses/\(item.courseID)/files/\(id)")!, token: token).0 }
                catch is CancellationError { throw CancellationError() }
                catch {
                    // Some courses disable Files navigation but permit their explicitly published links.
                    // Resolve only IDs found in this assignment/course's content or published modules.
                    data = try await api.get(URL(string: "https://canvas.sydney.edu.au/api/v1/files/\(id)")!, token: token).0
                }
                let object = try FeedbackAPI.object(data)
                guard object["id"] as? Int == id, object["locked_for_user"] as? Bool != true,
                      let file = FeedbackAPI.attachments([object]).first else { throw FeedbackError.invalidData }
                var fresh = file
                if let old = previous?.files.first(where: { $0.id == file.id && $0.updatedAt == file.updatedAt && $0.size == file.size }) {
                    fresh.localPath = old.localPath; fresh.contentHash = old.contentHash; fresh.cachedSize = old.cachedSize
                }
                filesByID[id] = fresh
            } catch is CancellationError { throw CancellationError() }
            catch { complete = false; plan.warnings.append("Course material file \(id) unavailable. It has not been included.") }
        }
        plan.linkedFileIDs = fileIDs
        plan.files = filesByID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        plan.links = Array(Set(plan.links.compactMap { AssignmentAssistContent.cleanURL($0)?.absoluteString })).sorted()
        if plan.outlineURL.isEmpty { plan.outlineURL = plan.links.first(where: { $0.contains("unit-of-study-outline") || $0.contains("/units/") }) ?? previous?.outlineURL ?? "" }
        plan.warnings = Array(Set(plan.warnings)).sorted()
        // Preserve prior metadata when an incomplete response would remove saved material.
        if !complete, let previous {
            for text in previous.texts where !plan.texts.contains(where: { $0.name == text.name }) {
                guard text.name != "03-Course-home.txt", !text.name.hasPrefix("Page-") || requestedPageNames.contains(text.name) else { continue }
                plan.texts.append(text)
            }
            for file in previous.files where !plan.files.contains(where: { $0.id == file.id }) { plan.files.append(file) }
        }
        try Task.checkCancellation()
        try save(plan)
        return plan
    }
    func save(_ plan: AssignmentAssistPlan) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(plan).write(to: directory.appendingPathComponent("\(plan.courseID)-\(plan.assignmentID).json"), options: .atomic)
    }
    func export(_ input: AssignmentAssistPlan, selected: Set<Int>, localFiles: [URL], to destination: URL, token: String?) async throws -> [String] {
        var plan = input
        let chosen = plan.files.filter { selected.contains($0.id) }
        guard chosen.reduce(0.0, { $0 + Double($1.size) }) <= 300 * 1024 * 1024 else { throw FeedbackError.unavailable("Choose fewer documents: each package supports up to 300 MB of course files.") }
        let fm = FileManager.default
        let temporary = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let root = temporary.appendingPathComponent(AssignmentAssistContent.safeName(plan.course + " - " + plan.title), isDirectory: true)
        let docs = root.appendingPathComponent("Teaching documents", isDirectory: true)
        try fm.createDirectory(at: docs, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temporary) }
        for text in plan.texts { try text.text.write(to: root.appendingPathComponent(AssignmentAssistContent.safeName(text.name)), atomically: true, encoding: .utf8) }
        var warnings = plan.warnings, included: [String] = []
        var totalBytes = 0
        for file in chosen {
            try Task.checkCancellation()
            do {
                guard file.size <= 100 * 1024 * 1024 else { throw FeedbackError.unavailable("File exceeds the 100 MB limit; use its Canvas source link.") }
                let saved = try await downloads.obtain(file, token: token ?? "")
                guard let url = FeedbackFiles.localURL(saved, directory: directory) else { throw FeedbackError.invalidData }
                totalBytes += saved.cachedSize ?? saved.size
                guard totalBytes <= 300 * 1024 * 1024 else { throw FeedbackError.unavailable("Package size exceeds 300 MB.") }
                let name = "\(file.id)-" + AssignmentAssistContent.safeName(file.name)
                try fm.copyItem(at: url, to: docs.appendingPathComponent(name))
                try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: docs.appendingPathComponent(name).path)
                included.append(name)
                if let index = plan.files.firstIndex(where: { $0.id == saved.id }) { plan.files[index] = saved }
            } catch is CancellationError { throw CancellationError() }
            catch { warnings.append("Not included: \(file.name). " + error.localizedDescription) }
        }
        for (index, url) in localFiles.enumerated() {
            try Task.checkCancellation()
            let size = (try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]))
            guard size.isRegularFile == true, (size.fileSize ?? Int.max) <= 100 * 1024 * 1024,
                  totalBytes + (size.fileSize ?? 0) <= 300 * 1024 * 1024 else { warnings.append("Not included: \(url.lastPathComponent) (file type or size limit)."); continue }
            totalBytes += size.fileSize ?? 0
            let name = "Local-\(index + 1)-" + AssignmentAssistContent.safeName(url.lastPathComponent)
            try fm.copyItem(at: url, to: docs.appendingPathComponent(name)); included.append(name)
        }
        let fileLinks = chosen.map { "https://canvas.sydney.edu.au/courses/\(plan.courseID)/files/\($0.id)" }
        let links = Array(Set(plan.links + fileLinks + (plan.outlineURL.isEmpty ? [] : [plan.outlineURL]))).compactMap { AssignmentAssistContent.cleanURL($0)?.absoluteString }.sorted()
        try links.joined(separator: "\n").write(to: root.appendingPathComponent("04-Source-links.txt"), atomically: true, encoding: .utf8)
        let readme = """
        \(plan.course) — \(plan.title)
        Assignment preparation package • \(ISO8601DateFormatter().string(from: Date()))

        Requirements and teaching materials only. Student submissions, marks and lecturer feedback are excluded.
        Review the contents and the unit's AI-use instructions before uploading to an AI service. Nothing has been sent automatically.
        The brief and syllabus retain supplied word limits, citation requirements and other instructions; these are source materials, not verified summaries.
        External resources are listed as links; their contents have not been downloaded. Canvas links may require your login.
        Unit outline: \(plan.outlineURL.isEmpty ? "Not found — add the unit outline URL before using this package." : AssignmentAssistContent.cleanURL(plan.outlineURL)?.absoluteString ?? "Invalid URL")

        Text documents:
        \(plan.texts.map { "- " + $0.name }.joined(separator: "\n"))

        Teaching documents included (\(included.count)):
        \(included.map { "- " + $0 }.joined(separator: "\n"))
        \(plan.files.count - chosen.count) course files were not selected.

        Collection notes and missing materials:
        \(warnings.isEmpty ? "No collection errors reported. Review relevance and external links; this is not a guarantee that all required resources were found." : warnings.map { "- " + $0 }.joined(separator: "\n"))
        """
        try readme.write(to: root.appendingPathComponent("00-READ-ME.txt"), atomically: true, encoding: .utf8)
        try save(plan)
        try Task.checkCancellation()
        let zip = temporary.appendingPathComponent("package.zip")
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--norsrc", "--noextattr", "--keepParent", root.path, zip.path]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw FeedbackError.unavailable("Could not create the ZIP. Your saved materials are unchanged.") }
        try Task.checkCancellation()
        // The native save panel authorises replacement; atomic write preserves an existing export on failure.
        try Data(contentsOf: zip, options: .mappedIfSafe).write(to: destination, options: .atomic)
        return warnings
    }
}
