import Foundation

// Plain, complete academic text. Presentation/disclosure state and private transport metadata never enter exports.
enum FeedbackExport {
    static func fileName(_ file: FeedbackAttachment, item: FeedbackItem) -> String {
        if item.attachments.contains(where: { $0.id == file.id }), file.isPDF, item.title.hasPrefix("Progress Presentation") {
            if let range = file.name.range(of: "[0-9]+(?=of[0-9]+)", options: .regularExpression) {
                return "Presentation " + file.name[range] + " — Feedback.pdf"
            }
            return item.title.replacingOccurrences(of: "Progress ", with: "") + " — Feedback.pdf"
        }
        return file.name
    }

    static func hasRubric(_ item: FeedbackItem) -> Bool { !item.rubric.isEmpty || !item.assessments.isEmpty }
    private static func context(_ item: FeedbackItem) -> [String] {
        [item.course + " — " + item.originalTitle, "Source: Canvas", ""]
    }
    static func feedback(_ item: FeedbackItem) -> String {
        var lines = context(item)
        lines.append(item.markLabel.map { "Released Canvas mark: " + $0 } ?? "Canvas mark: not available. " + item.subtitle + ".")
        if !item.gradeMatchesCurrent && item.markLabel != nil { lines.append("This mark is for a previous submission attempt.") }
        lines += ["", "Lecturer feedback"]
        if item.comments.isEmpty { lines.append("No lecturer comments are available from Canvas.") }
        for comment in item.comments {
            lines += [comment.author + " · " + FeedbackFormat.time(comment.createdAt), comment.text, ""]
        }
        if !item.attachments.isEmpty {
            lines.append("Feedback attachments (documents are separate from this copied text):")
            lines += item.attachments.map { "- " + $0.name }
            if item.rubricState == .document { lines.append("The rubric is included in the feedback PDF; its contents are not transcribed here.") }
        }
        lines += ["", "Submission: " + item.workflowState, "Submitted: " + FeedbackFormat.time(item.submittedAt)]
        if let attempt = item.attempt { lines.append("Submission attempt " + String(attempt)) }
        if item.late { lines.append("Canvas flags this submission as late.") }
        if item.missing { lines.append("Canvas flags this submission as missing.") }
        lines.append("Last downloaded: " + FeedbackFormat.time(item.checkedAt))
        return lines.joined(separator: "\n")
    }
    static func rubric(_ item: FeedbackItem) -> String {
        var lines = context(item)
        guard hasRubric(item) else { return (lines + ["No structured rubric is available. Open the feedback document for any rubric it contains."]).joined(separator: "\n") }
        lines += [item.assessments.isEmpty ? "Marking criteria (no assessed rubric returned)" : "Assessed rubric", item.rubricTitle]
        if let type = item.assessmentType { lines.append("Assessment type: " + type) }
        if let attempt = item.assessmentAttempt { lines.append("Rubric for submission attempt " + String(attempt)) }
        for (index, criterion) in item.rubric.enumerated() {
            lines += ["", "\(index + 1). " + criterion.description]
            if !criterion.longDescription.isEmpty { lines.append(criterion.longDescription) }
            if !item.hideRubricPoints, let maximum = criterion.points { lines.append("Maximum: " + FeedbackFormat.number(maximum)) }
            if criterion.usesRange { lines.append("Rating points use ranges.") }
            if let assessment = item.assessments[criterion.id] {
                append(assessment, maximum: criterion.points, hidePoints: item.hideRubricPoints, to: &lines)
                if let ratingID = assessment.ratingID, let rating = criterion.ratings.first(where: { $0.id == ratingID }) {
                    lines.append("Selected rating: " + rating.description)
                }
            }
            if !criterion.ratings.isEmpty { lines.append("Rating descriptions:") }
            for rating in criterion.ratings {
                let points = !item.hideRubricPoints ? rating.points.map { " (" + FeedbackFormat.number($0) + ")" } ?? "" : ""
                lines.append("- " + rating.description + points)
                if !rating.longDescription.isEmpty { lines.append("  " + rating.longDescription) }
            }
        }
        for id in item.assessments.keys.sorted() where !item.rubric.contains(where: { $0.id == id }) {
            lines += ["", "Additional criterion feedback (definition unavailable)"]
            append(item.assessments[id]!, maximum: nil, hidePoints: item.hideRubricPoints, to: &lines)
        }
        lines += ["", "Last downloaded: " + FeedbackFormat.time(item.checkedAt)]
        return lines.joined(separator: "\n")
    }
    private static func append(_ assessment: FeedbackAssessment, maximum: Double?, hidePoints: Bool, to lines: inout [String]) {
        if !hidePoints, let points = assessment.points {
            lines.append("Awarded: " + FeedbackFormat.number(points) + (maximum.map { "/" + FeedbackFormat.number($0) } ?? ""))
        }
        if let comment = assessment.comments, !comment.isEmpty { lines.append("Assessor comment: " + comment) }
    }
}

enum FeedbackReadingSize {
    static let maximum = 10
    static func clamped(_ step: Int) -> Int { min(maximum, max(0, step)) }
    static func scale(_ step: Int) -> Double { 1 + Double(clamped(step)) * 0.1 }
}
