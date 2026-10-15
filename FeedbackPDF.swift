import Foundation
import CoreTransferable
import UniformTypeIdentifiers

// Export a copy through macOS file transfer; receivers cannot edit the app's managed original.
struct FeedbackPDF: Transferable {
    let url: URL
    let name: String
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { item in
            guard FileManager.default.isReadableFile(atPath: item.url.path) else { throw CocoaError(.fileNoSuchFile) }
            // FileRepresentation uses the source file's actual name; its suggestion alone is not
            // enough for Finder. Use a system-managed replacement directory for a named export copy.
            let directory = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: FileManager.default.temporaryDirectory, create: true)
            let filename = URL(fileURLWithPath: item.name).lastPathComponent
            let exported = directory.appendingPathComponent(filename.isEmpty || filename == "." || filename == ".." ? "Feedback.pdf" : filename)
            try FileManager.default.copyItem(at: item.url, to: exported)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: exported.path)
            return SentTransferredFile(exported, allowAccessingOriginalFile: false)
        }.suggestedFileName { $0.name }
    }
}
