import Foundation
@main struct FeedbackPersistenceChecks {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("feedback-checks-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try FeedbackRepository.open(directory: directory)
        var values = FeedbackDesignFixture.items
        var submissionFile = values[0].attachments[0]; submissionFile.id = 800; submissionFile.name = "My submission.pdf"
        values[0].submissionFiles = [submissionFile]
        let input = FeedbackFetchResult(courses: [FeedbackCourseResult(courseID: 1, items: values, warning: nil)], userID: 1, checkedAt: "2026-10-15T06:21:00Z")
        _ = try await repository.merge(input)
        let reopened = try FeedbackRepository.open(directory: directory)
        var restored = try await reopened.load()
        precondition(restored.count == values.count)
        precondition(restored.last { !$0.rubric.isEmpty }!.rubric[0].ratings[0].longDescription.contains("Iterative"))
        _ = try await reopened.merge(input)
        let count = try await reopened.load().count
        precondition(count == values.count)
        var savedSubmission = submissionFile
        savedSubmission.localPath = "Files/submission.pdf"; savedSubmission.contentHash = "submission-bytes"; savedSubmission.cachedSize = 20
        _ = try await reopened.updateAttachment(itemID: values[0].id, file: savedSubmission, expected: submissionFile)
        _ = try await reopened.merge(input)
        let submissionRestored = try await FeedbackRepository.open(directory: directory).load().first { $0.id == values[0].id }!
        precondition(submissionRestored.submissionFiles[0].localPath == savedSubmission.localPath, "Current submission downloads must survive refresh and restart")
        _ = try await reopened.merge(FeedbackFetchResult(courses: [FeedbackCourseResult(courseID: 1, items: [], warning: "Offline")], userID: 1, checkedAt: "later"))
        restored = try await reopened.load()
        precondition(restored.count == values.count, "Failed course must preserve all records")
        precondition(restored[0].checkedAt != "later")
        let expected = values[0].attachments[0]
        var revised = input
        revised.courses[0].items[0].comments[0].attachments[0].updatedAt = "revision-two"
        _ = try await reopened.merge(revised)
        var oldDownload = expected; oldDownload.localPath = "Files/old.pdf"; oldDownload.contentHash = "old-bytes"
        var rejected = false
        do { _ = try await reopened.updateAttachment(itemID: values[0].id, file: oldDownload, expected: expected) } catch { rejected = true }
        if !rejected { print("FAIL: stale download overwrote current attachment revision"); exit(1) }
        let afterRace = try await reopened.load().first { $0.id == values[0].id }!
        precondition(afterRace.attachments[0].updatedAt == "revision-two" && afterRace.attachments[0].localPath == nil)
        let readOnly = try FeedbackRepository.open(directory: directory, allowsSave: false)
        var changed = input; changed.courses[0].items[0].title = "Changed"
        do { _ = try await readOnly.merge(changed); preconditionFailure("Read-only store accepted update") } catch {}
        let final = try await FeedbackRepository.open(directory: directory).load()
        precondition(final.count == values.count)
        print("PASS: SwiftData disk reopen, rubric graph, stable merge, failed-course preservation and failed-save recovery")
    }
}
