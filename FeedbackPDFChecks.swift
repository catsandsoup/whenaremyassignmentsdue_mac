import Foundation
import CoreTransferable
import UniformTypeIdentifiers
@main struct FeedbackPDFChecks {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("internal-content-hash.pdf")
        let bytes = Data("%PDF-1.7\nSynthetic transfer fixture".utf8)
        try bytes.write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: url.path)
        let item = FeedbackPDF(url: url, name: "Assignment Feedback.pdf")
        let exported = try await item.exported(as: .pdf)
        precondition(exported == bytes, "Drag/share must transfer file bytes, not URL text")
        let destination = root.appendingPathComponent("Export")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let exportedURL = try await item.export(to: destination, contentType: .pdf)
        let exportedBytes = try Data(contentsOf: exportedURL)
        precondition(exportedBytes == bytes)
        precondition(exportedURL.lastPathComponent == "Assignment Feedback.pdf", "Use the source filename instead of the internal hash")
        let permissions = try FileManager.default.attributesOfItem(atPath: exportedURL.path)[.posixPermissions] as! Int
        precondition(permissions & 0o200 != 0, "Exported copies must be editable")
        try Data("Edited copy".utf8).write(to: exportedURL)
        let original = try Data(contentsOf: url)
        precondition(original == bytes, "Editing an exported copy must not modify the managed original")
        try FileManager.default.removeItem(at: url)
        do { _ = try await item.exported(as: .pdf); preconditionFailure("Missing file exported") } catch {}
        print("PASS: native PDF Transferable exports document bytes and fails for a missing file")
    }
}
