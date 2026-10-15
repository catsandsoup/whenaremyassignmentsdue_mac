import Foundation
import AppKit
import PDFKit
@main struct FeedbackFileChecks {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("feedback-files-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let files = FeedbackFiles(directory: root)
        let file = FeedbackAttachment(id: 1, name: "Feedback.pdf", url: "https://canvas.sydney.edu.au/files/1/download", contentType: "application/pdf", size: 0)
        do { _ = try await files.commit(Data("<html>Sign in</html>".utf8), file: file); preconditionFailure("Login page accepted as PDF") } catch {}
        let bytes = NSMutableData()
        let consumer = CGDataConsumer(data: bytes as CFMutableData)!
        var bounds = CGRect(x: 0, y: 0, width: 200, height: 200)
        let graphics = CGContext(consumer: consumer, mediaBox: &bounds, nil)!
        graphics.beginPDFPage(nil); graphics.endPDFPage(); graphics.closePDF()
        let data = bytes as Data
        let saved = try await files.commit(data, file: file)
        let local = FeedbackFiles.localURL(saved, directory: root)
        precondition(local != nil && saved.contentHash != nil)
        let permissions = try FileManager.default.attributesOfItem(atPath: local!.path)[.posixPermissions] as! Int
        precondition(permissions & 0o222 == 0, "Managed originals must not be silently edited by a PDF handler")
        var other = file; other.id = 2
        let duplicate = try await files.commit(data, file: other)
        precondition(duplicate.localPath == saved.localPath && duplicate.id != saved.id)
        var escape = saved; escape.localPath = "../outside.pdf"
        precondition(FeedbackFiles.localURL(escape, directory: root) == nil)
        var request = URLRequest(url: URL(string: "https://storage.example.test/file.pdf")!)
        request.setValue("Bearer test", forHTTPHeaderField: "Authorization")
        precondition(FeedbackRedirectPolicy.request(request, allowFiles: true)?.value(forHTTPHeaderField: "Authorization") == nil)
        precondition(FeedbackRedirectPolicy.request(request, allowFiles: false) == nil)
        try FileManager.default.removeItem(at: local!)
        precondition(FeedbackFiles.localURL(saved, directory: root) == nil)
        print("PASS: reject login HTML, validate PDF, atomic content-addressed local copies, duplicate provenance, missing files/path escapes and credential-safe redirects")
    }
}
