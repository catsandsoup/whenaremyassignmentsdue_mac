import Foundation
import CoreTransferable
import UniformTypeIdentifiers

struct AssignmentMaterial: Identifiable, Sendable {
    var id: String
    var name: String
    var url: URL?
    var note: String = ""
    var source: URL? = nil
}

// Typed native file representations let receivers accept PDFs/text as files rather than URL strings.
struct AssignmentMaterialFile: Transferable {
    let url: URL
    var exportName: String? = nil
    var name: String { AssignmentAssistContent.safeName(exportName ?? url.lastPathComponent) }
    var contentType: UTType { UTType(filenameExtension: url.pathExtension) ?? .data }
    static var transferRepresentation: some TransferRepresentation {
        file(.pdf).exportingCondition { $0.contentType.conforms(to: .pdf) }
        file(.plainText).exportingCondition { $0.contentType.conforms(to: .plainText) }
        file(.png).exportingCondition { $0.contentType.conforms(to: .png) }
        file(.jpeg).exportingCondition { $0.contentType.conforms(to: .jpeg) }
        file(UTType("org.openxmlformats.wordprocessingml.document")!).exportingCondition { $0.url.pathExtension.lowercased() == "docx" }
        file(UTType("org.openxmlformats.presentationml.presentation")!).exportingCondition { $0.url.pathExtension.lowercased() == "pptx" }
        file(.commaSeparatedText).exportingCondition { $0.contentType.conforms(to: .commaSeparatedText) }
        file(.data)
    }
    private static func file(_ type: UTType) -> some TransferRepresentation<AssignmentMaterialFile> {
        FileRepresentation(exportedContentType: type) { (item: AssignmentMaterialFile) in
            guard FileManager.default.isReadableFile(atPath: item.url.path) else { throw CocoaError(.fileNoSuchFile) }
            let folder = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: FileManager.default.temporaryDirectory, create: true)
            let copy = folder.appendingPathComponent(item.name)
            try FileManager.default.copyItem(at: item.url, to: copy)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: copy.path)
            return SentTransferredFile(copy, allowAccessingOriginalFile: false)
        }.suggestedFileName { $0.name }
    }
}

enum AssignmentMaterialFiles {
    static func writeTexts(_ plan: AssignmentAssistPlan, directory: URL) throws -> [AssignmentMaterial] {
        let fingerprint = plan.course + plan.title + plan.texts.map { $0.name + $0.text }.joined() + plan.links.sorted().joined() + plan.outlineURL
        let folder = directory.appendingPathComponent(FeedbackFiles.digest(Data(fingerprint.utf8)), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var result: [AssignmentMaterial] = []
        var title = plan.title
        while title.utf8.count > 40 { title.removeLast() }
        for (index, text) in plan.texts.enumerated() {
            let label: String
            switch text.name {
            case "01-Assignment-brief.txt": label = "Assignment brief.txt"
            case "02-Marking-rubric.txt": label = "Complete marking rubric.txt"
            case "03-Course-syllabus.txt": label = "Course syllabus.txt"
            case "03-Course-home.txt": label = "Course home.txt"
            default: label = text.name
            }
            let unavailable = (plan.unavailableTextNames ?? []).contains(text.name)
                || text.text.contains("No structured rubric was supplied.")
                || text.text.contains("No assignment description was supplied.")
            if unavailable {
                result.append(AssignmentMaterial(id: text.name, name: label, note: "Not supplied by Canvas"))
                continue
            }
            let name = AssignmentAssistContent.safeName(String(format: "%02d", index + 1) + " - " + plan.course + " - " + title + " - " + label)
            let url = folder.appendingPathComponent(name)
            try text.text.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: url.path)
            result.append(AssignmentMaterial(id: text.name, name: label, url: url, note: "Ready to drag"))
        }
        var links = plan.links
        if let outline = AssignmentAssistContent.cleanURL(plan.outlineURL) { links.append(outline.absoluteString) }
        links = Array(Set(links.compactMap { AssignmentAssistContent.cleanURL($0)?.absoluteString })).sorted()
        let source = folder.appendingPathComponent(AssignmentAssistContent.safeName("Sources - " + plan.course + " - " + title + ".txt"))
        try (plan.course + " — " + plan.title + "\n\n" + links.joined(separator: "\n")).write(to: source, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: source.path)
        result.append(AssignmentMaterial(id: "sources", name: "Source links.txt", url: source, note: "Canvas and linked resources"))
        return result
    }
    static func saveAll(_ materials: [AssignmentMaterial], plan: AssignmentAssistPlan, to downloads: URL) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: downloads, withIntermediateDirectories: true)
        let staging = downloads.appendingPathComponent(".AssignmentMaterials-" + UUID().uuidString)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: staging) }
        for material in materials {
            try Task.checkCancellation()
            guard let source = material.url else { continue }
            let destination = staging.appendingPathComponent(source.lastPathComponent)
            try fm.copyItem(at: source, to: destination)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        }
        let unavailable = materials.filter { $0.url == nil }.map { $0.name + ": " + $0.note }
        let notes = [plan.course + " — " + plan.title, "Requirements and teaching materials from Canvas.", "Saved: " + ISO8601DateFormatter().string(from: Date()), "", "Collection notes:"] + plan.warnings + unavailable
        try notes.joined(separator: "\n").write(to: staging.appendingPathComponent("Collection notes.txt"), atomically: true, encoding: .utf8)
        let base = AssignmentAssistContent.safeName(plan.course + " - " + plan.title)
        var destination = downloads.appendingPathComponent(base), index = 2
        while fm.fileExists(atPath: destination.path) { destination = downloads.appendingPathComponent(base + " (\(index))"); index += 1 }
        try Task.checkCancellation()
        try fm.moveItem(at: staging, to: destination)
        return destination
    }
}

extension AssignmentAssistService {
    func cachedPlan(_ item: FeedbackItem) -> AssignmentAssistPlan {
        let url = directory.appendingPathComponent("\(item.courseID)-\(item.assignmentID).json")
        return (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(AssignmentAssistPlan.self, from: $0) } ?? AssignmentAssistContent.plan(item)
    }
    func readyTexts(_ plan: AssignmentAssistPlan) throws -> [AssignmentMaterial] {
        try AssignmentMaterialFiles.writeTexts(plan, directory: directory.appendingPathComponent("Ready"))
    }
    func readyFile(_ file: FeedbackAttachment, plan: AssignmentAssistPlan, token: String?) async throws -> AssignmentMaterial {
        guard file.size <= 100 * 1024 * 1024 else { throw FeedbackError.unavailable("Over 100 MB — open the original in Canvas") }
        let saved = try await downloads.obtain(file, token: token ?? "")
        try Task.checkCancellation()
        guard let source = FeedbackFiles.localURL(saved, directory: directory) else { throw CocoaError(.fileNoSuchFile) }
        let folder = directory.appendingPathComponent("Ready/Documents/" + (saved.contentHash ?? UUID().uuidString))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let target = folder.appendingPathComponent(AssignmentAssistContent.safeName("Canvas-\(file.id)-" + file.name))
        if !FileManager.default.fileExists(atPath: target.path) { try FileManager.default.copyItem(at: source, to: target) }
        var latest = cachedPlanFor(plan)
        if let index = latest.files.firstIndex(where: { $0.id == file.id && $0.updatedAt == file.updatedAt }) { latest.files[index] = saved; try save(latest) }
        return AssignmentMaterial(id: "file-\(file.id)", name: file.name, url: target, note: "Ready to drag", source: URL(string: "https://canvas.sydney.edu.au/courses/\(plan.courseID)/files/\(file.id)"))
    }
    private func cachedPlanFor(_ fallback: AssignmentAssistPlan) -> AssignmentAssistPlan {
        let url = directory.appendingPathComponent("\(fallback.courseID)-\(fallback.assignmentID).json")
        return (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(AssignmentAssistPlan.self, from: $0) } ?? fallback
    }
    func saveReady(_ materials: [AssignmentMaterial], plan: AssignmentAssistPlan, to downloads: URL) throws -> URL {
        try AssignmentMaterialFiles.saveAll(materials, plan: plan, to: downloads)
    }
}
