import Foundation
import CoreTransferable
import UniformTypeIdentifiers

@main struct AssignmentMaterialChecks {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var plan = AssignmentAssistPlan(course: "TEST6001", title: "Previous assessment", courseID: 1, assignmentID: 42)
        plan.texts = [AssistText(name: "01-Assignment-brief.txt", text: "Assignment instructions"), AssistText(name: "02-Marking-rubric.txt", text: "Complete criterion\nCollapsed rating description")]
        plan.outlineURL = "https://example.com/outline?year=2026"
        let materials = try AssignmentMaterialFiles.writeTexts(plan, directory: root)
        guard let rubric = materials.first(where: { $0.id == "02-Marking-rubric.txt" }), let url = rubric.url else { print("FAIL: previous assessment rubric must be a ready, named file"); exit(1) }
        let text = try String(contentsOf: url, encoding: .utf8)
        precondition(text.contains("Collapsed rating description"))
        precondition(url.lastPathComponent.contains("Previous assessment"))
        var assessed = FeedbackDesignFixture.items.first!
        assessed.rubric = [FeedbackCriterion(id: "one", description: "Evidence", longDescription: "Complete criterion", points: 5, usesRange: false, ratings: [FeedbackRating(id: "top", description: "Excellent", longDescription: "Collapsed description", points: 5)])]
        assessed.assessments = ["one": FeedbackAssessment(points: 3, comments: "Assessor comment for reuse", ratingID: "top")]
        assessed.comments = [FeedbackComment(id: 1, author: "Lecturer", text: "Overall feedback for copying", createdAt: nil, attachments: [])]
        var gradedPlan = plan
        gradedPlan.texts = [AssistText(name: "Assessed rubric.txt", text: FeedbackExport.rubric(assessed))]
        let gradedFiles = try AssignmentMaterialFiles.writeTexts(gradedPlan, directory: root)
        let graded = try String(contentsOf: gradedFiles.first!.url!, encoding: .utf8)
        precondition(graded.contains("Assessor comment for reuse") && graded.contains("Collapsed description"))
        precondition(FeedbackExport.feedback(assessed).contains("Overall feedback for copying"))
        let received = try await receive(AssignmentMaterialFile(url: url), type: .plainText)
        precondition(received.0 == url.lastPathComponent && received.1 == Data(text.utf8), "Native drag receiver needs the exact named rubric bytes")
        let opaque = root.appendingPathComponent("opaque-content-hash.pdf")
        try Data("%PDF-synthetic-feedback".utf8).write(to: opaque)
        let namedFeedback = try await receive(AssignmentMaterialFile(url: opaque, exportName: "Previous assessment — Feedback.pdf"), type: .pdf)
        precondition(namedFeedback.0 == "Previous assessment — Feedback.pdf" && namedFeedback.1 == Data("%PDF-synthetic-feedback".utf8), "Feedback drag/share must use its readable filename, not a content hash")
        let downloads = root.appendingPathComponent("Downloads")
        let saved = try AssignmentMaterialFiles.saveAll(materials, plan: plan, to: downloads)
        let savedBytes = try Data(contentsOf: saved.appendingPathComponent(url.lastPathComponent))
        precondition(savedBytes == Data(text.utf8))
        let second = try AssignmentMaterialFiles.saveAll(materials, plan: plan, to: downloads)
        precondition(saved != second && second.lastPathComponent.hasSuffix(" (2)"), "Saving again must not overwrite a student's earlier export")
        try Data("User edited exported rubric".utf8).write(to: saved.appendingPathComponent(url.lastPathComponent))
        let original = try String(contentsOf: url, encoding: .utf8)
        precondition(original == text, "Saved and dragged copies cannot change the managed rubric")
        plan.title = String(repeating: "📚", count: 180)
        let long = try AssignmentMaterialFiles.writeTexts(plan, directory: root)
        let longURLs = long.compactMap(\.url)
        precondition(Set(longURLs).count == longURLs.count && longURLs.allSatisfy { $0.lastPathComponent.utf8.count <= 180 })
        precondition(longURLs.allSatisfy { $0.lastPathComponent.utf8.count <= 112 }, "Generated export names need concise context rather than the complete long assessment title")
        for (name, type, bytes) in [("Feedback — previous.pdf", UTType.pdf, Data("%PDF-synthetic".utf8)), ("Diagram.png", .png, Data([1,2,3])), ("Reading.docx", UTType("org.openxmlformats.wordprocessingml.document")!, Data([4,5,6]))] {
            let file = root.appendingPathComponent(name); try bytes.write(to: file)
            let result = try await receive(AssignmentMaterialFile(url: file), type: type)
            precondition(result.0 == name && result.1 == bytes, "Typed file transfer must preserve filename and original bytes")
        }
        let missing = AssignmentMaterial(id: "missing", name: "Unavailable guide.pdf", note: "Permission denied")
        let partial = try AssignmentMaterialFiles.saveAll(materials + [missing], plan: plan, to: downloads)
        let notes = try String(contentsOf: partial.appendingPathComponent("Collection notes.txt"), encoding: .utf8)
        precondition(notes.contains("Unavailable guide.pdf: Permission denied"))
        let serviceRoot = root.appendingPathComponent("Service")
        let cache = FeedbackFiles(directory: serviceRoot)
        let descriptor = FeedbackAttachment(id: 9, name: "Reading.txt", url: "https://canvas.sydney.edu.au/files/9/download", contentType: "text/plain", size: 0)
        let cached = try await cache.commit(Data("Original Canvas document".utf8), file: descriptor)
        plan.files = [cached]; plan.linkedFileIDs = [9]
        let service = AssignmentAssistService(directory: serviceRoot)
        let ready = try await service.readyFile(cached, plan: plan, token: nil)
        let readyBytes = try Data(contentsOf: ready.url!)
        precondition(readyBytes == Data("Original Canvas document".utf8), "Cached Canvas files must be readied without a credential or network call")
        print("PASS: ready rubric files, native typed drag receivers, exact file bytes, source context, Unicode names, atomic Downloads copies, repeat-save preservation and offline Canvas file readiness")
    }
    private static func receive(_ file: AssignmentMaterialFile, type: UTType) async throws -> (String, Data) {
        let provider = NSItemProvider(); provider.register(file)
        return try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                do {
                    if let error { throw error }
                    guard let url else { throw CocoaError(.fileNoSuchFile) }
                    continuation.resume(returning: (url.lastPathComponent, try Data(contentsOf: url)))
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
}
