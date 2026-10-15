import Foundation
@main struct FeedbackExportChecks {
    static func main() {
        var item = FeedbackDesignFixture.items.last!
        item.assessments["one"] = FeedbackAssessment(points: 0, comments: "Improve evidence", ratingID: "best")
        item.assessmentAttempt = 2; item.assessmentType = "peer_review"
        item.rubric[0].ratings.append(FeedbackRating(id: "low", description: "Near", longDescription: "Every collapsed rating must be copied.", points: 0.5))
        let rubric = FeedbackExport.rubric(item)
        precondition(rubric.contains("FINC6001") && rubric.contains("Written Report"))
        precondition(rubric.contains("Every collapsed rating") && rubric.contains("Iterative prompts"))
        precondition(rubric.contains("Awarded: 0/2") && rubric.contains("0.5") && rubric.contains("Improve evidence"))
        precondition(rubric.contains("peer_review") && rubric.contains("attempt 2"))
        precondition(rubric.range(of: "Exceeds")!.lowerBound < rubric.range(of: "Near")!.lowerBound)
        item.hideRubricPoints = true
        let hidden = FeedbackExport.rubric(item)
        precondition(!hidden.contains("0/2") && !hidden.contains("0.5") && !hidden.contains("Maximum:"))
        precondition(hidden.contains("Improve evidence"))
        var feedback = FeedbackDesignFixture.items[0]
        feedback.score = 99; feedback.grade = "99"; feedback.postedAt = nil
        feedback.comments[0].attachments[0].url += "?verifier=PRIVATE_SECRET"
        feedback.comments[0].attachments[0].localPath = "Files/PRIVATE_PATH.pdf"
        let text = FeedbackExport.feedback(feedback)
        precondition(text.contains(feedback.course) && text.contains(feedback.originalTitle) && text.contains("Please see attached files."))
        precondition(text.contains(feedback.attachments[0].name))
        precondition(!text.contains("99") && !text.contains("PRIVATE_SECRET") && !text.contains("PRIVATE_PATH"))
        feedback.postedAt = "2026-10-15T00:00:00Z"; feedback.score = 0; feedback.grade = "0"; feedback.pointsPossible = 5; feedback.gradeMatchesCurrent = false
        let zero = FeedbackExport.feedback(feedback)
        precondition(zero.contains("0/5") && zero.contains("previous submission attempt"))
        precondition(!FeedbackExport.hasRubric(FeedbackDesignFixture.items[0]))
        precondition(FeedbackExport.hasRubric(item))
        precondition(FeedbackReadingSize.clamped(-100) == 0 && FeedbackReadingSize.clamped(100) == FeedbackReadingSize.maximum)
        precondition(FeedbackReadingSize.scale(0) == 1 && FeedbackReadingSize.scale(FeedbackReadingSize.maximum) >= 2.0)
        print("PASS: complete rubric/feedback copies preserve context, collapsed ratings, zero/fractions/type/attempt and hidden points; exclude unposted marks, signed URLs and private paths; bounded reading size")
    }
}
