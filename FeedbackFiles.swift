import Foundation
import CryptoKit
import PDFKit

actor FeedbackFiles {
    let directory: URL
    let allowsHTMLTeachingFiles: Bool
    let session: URLSession
    init(directory: URL, session: URLSession? = nil, allowsHTMLTeachingFiles: Bool = false) {
        self.allowsHTMLTeachingFiles = allowsHTMLTeachingFiles
        self.directory = directory
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 180
        self.session = session ?? URLSession(configuration: config, delegate: FeedbackRedirectPolicy(allowFiles: true), delegateQueue: nil)
    }
    nonisolated static func localURL(_ file: FeedbackAttachment, directory: URL) -> URL? {
        guard let relative = file.localPath, !relative.hasPrefix("/"), !relative.split(separator: "/").contains("..") else { return nil }
        let root = directory.resolvingSymlinksInPath().standardizedFileURL
        let url = root.appendingPathComponent(relative).resolvingSymlinksInPath().standardizedFileURL
        guard url.path.hasPrefix(root.path + "/"), FileManager.default.isReadableFile(atPath: url.path) else { return nil }
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path), let size = attributes[.size] as? Int, (file.cachedSize ?? file.size) > 0, size != (file.cachedSize ?? file.size) { return nil }
        return url
    }
    func obtain(_ file: FeedbackAttachment, token: String) async throws -> FeedbackAttachment {
        if let local = Self.localURL(file, directory: directory),
           let data = try? Data(contentsOf: local), Self.digest(data) == file.contentHash {
            try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: local.path)
            return file
        }
        guard !token.isEmpty else { throw FeedbackError.unavailable("This file has not been saved on this Mac. Update your API key to download it.") }
        guard let url = URL(string: file.url), url.scheme == "https" else { throw FeedbackError.invalidData }
        var request = URLRequest(url: url)
        if url.host == "canvas.sydney.edu.au" { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        let (temporary, http) = try await CanvasNetworking.download(for:request,session:session)
        defer { try? FileManager.default.removeItem(at: temporary) }
        switch http.statusCode {
        case 401: throw CanvasAPIError.invalidKey
        case 403: throw CanvasAPIError.forbidden
        case 200..<300: break
        default: throw CanvasAPIError.server(http.statusCode)
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: temporary.path)
        guard (attributes[.size] as? Int ?? Int.max) <= 100 * 1024 * 1024 else { throw FeedbackError.unavailable("This attachment is too large for the feedback cache (100 MB limit).") }
        let data = try Data(contentsOf: temporary)
        return try commit(data, file: file)
    }
    func commit(_ data: Data, file: FeedbackAttachment) throws -> FeedbackAttachment {
        guard !data.isEmpty else { throw FeedbackError.invalidData }
        let beginning = String(decoding: data.prefix(512), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let expectedHTML = allowsHTMLTeachingFiles && ["html", "htm"].contains(URL(fileURLWithPath:file.name).pathExtension.lowercased()) && file.contentType.lowercased().hasPrefix("text/html")
        guard expectedHTML || (!beginning.hasPrefix("<!doctype html") && !beginning.hasPrefix("<html")) else { throw FeedbackError.unavailable("Canvas returned a web page instead of the attachment. Your saved files are unchanged.") }
        var copy = file
        if file.isPDF {
            guard data.starts(with: Data("%PDF-".utf8)), let document = PDFDocument(data: data), document.pageCount > 0 else { throw FeedbackError.unavailable("The downloaded file is not a valid PDF. Your saved files are unchanged.") }
            let text = (document.string ?? "").lowercased()
            copy.containsRubric = text.contains("assessment criteria") || text.contains("marking rubric") || text.contains("assessment rubric")
            copy.containsResult = text.range(of: #"mark\s+[0-9]+(?:\.[0-9]+)?\s*/\s*[0-9]+"#, options: .regularExpression) != nil
        }
        let digest = Self.digest(data)
        let fileExtension = file.isPDF ? "pdf" : URL(fileURLWithPath: file.name).pathExtension.lowercased().filter { $0.isLetter || $0.isNumber }
        let relative = "Files/" + digest + (fileExtension.isEmpty ? "" : "." + fileExtension)
        let target = directory.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        // Atomic rename occurs before the database references this content; no partial file is ever marked saved.
        if !FileManager.default.fileExists(atPath: target.path) || (try? Data(contentsOf: target)).map(Self.digest) != digest {
            try data.write(to: target, options: .atomic)
        }
        // Managed originals are read-only. Native document apps can offer Duplicate/Save for edits.
        try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: target.path)
        copy.contentHash = digest; copy.localPath = relative; copy.cachedSize = data.count
        return copy
    }
    nonisolated static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
