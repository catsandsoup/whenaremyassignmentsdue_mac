import Foundation
// Synthetic design/test records. Never populated from the user's private feedback.
enum FeedbackDesignFixture {
    static var items: [FeedbackItem] {
        let pdf = FeedbackAttachment(id: 1, name: "Presentation 2 — Feedback.pdf", url: "https://canvas.sydney.edu.au/files/1/download", contentType: "application/pdf", size: 108190, containsRubric: true, containsResult: true)
        func item(_ id: Int, _ course: String, _ title: String) -> FeedbackItem {
            FeedbackItem(id: "design:\(id)", assignmentID: id, courseID: 1, userID: 1, course: course, title: title, originalTitle: title, pointsPossible: nil, score: nil, grade: nil, postedAt: nil, submittedAt: nil, attempt: 1, workflowState: "submitted", checkedAt: "2026-10-15T06:21:00Z")
        }
        var p2 = item(2, "SIEN6007", "Progress Presentation 2")
        p2.comments = [FeedbackComment(id: 2, author: "Lecturer", text: "Please see attached files.", createdAt: "2026-09-18T10:50:59Z", attachments: [pdf])]
        var p1 = item(1, "SIEN6007", "Progress Presentation 1")
        var pdf1 = pdf; pdf1.id = 2; pdf1.name = "Presentation 1 — Feedback.pdf"
        p1.comments = [FeedbackComment(id: 1, author: "Lecturer", text: "Please find your written feedback attached.", createdAt: "2026-09-08T00:13:23Z", attachments: [pdf1])]
        var p3 = item(3, "SIEN6007", "Progress Presentation 3")
        p3.comments = [FeedbackComment(id: 3, author: "Lecturer", text: "I’m re-attaching the pdf here again.", createdAt: "2026-10-12T07:11:27Z", attachments: [pdf1])]
        var ai = item(4, "IBUS6020", "AI Feedback Task 1")
        ai.pointsPossible = 5; ai.score = 3.8; ai.grade = "3.8"; ai.postedAt = "2026-09-15T00:26:54Z"
        ai.comments = [FeedbackComment(id: 4, author: "Lecturer", text: "The submission uses relevant sources. Compare their differences more closely to strengthen the critical analysis.", createdAt: ai.postedAt, attachments: [])]
        let individual = item(5, "FINC6017", "Individual assignment")
        var report = item(6, "FINC6001", "Written Report")
        report.rubric = [FeedbackCriterion(id: "one", description: "AI Generated Investment Analysis", longDescription: "Explain and evaluate the analysis.", points: 2, usesRange: true, ratings: [FeedbackRating(id: "best", description: "Exceeds", longDescription: "AI tool clearly named. Iterative prompts are documented and show meaningful refinement.", points: 2)])]
        return [p2, p1, p3, ai, individual, report]
    }
}
